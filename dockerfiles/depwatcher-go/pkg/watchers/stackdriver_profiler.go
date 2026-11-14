package watchers

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const stackdriverProfilerBucket = "https://storage.googleapis.com/storage/v1/b/cloud-profiler/o"
const stackdriverProfilerDownloadBase = "https://storage.googleapis.com/cloud-profiler/java/"

// Google names its releases cloud-profiler-java-agent_YYYYMMDD_RCNN.tar.gz. A date version is not a semantic
// version, so the version resolver of the buildpacks cannot use it. The watcher publishes it as 0.YYYYMMDD.N
// instead (20261026_RC00 becomes 0.20261026.0): it sorts by date and then by release candidate number, and it
// is always newer than the 0.x label the Java buildpack used before.
var stackdriverProfilerArtifactVersionPattern = regexp.MustCompile(`^(\d{8})_RC(\d+)$`)
var stackdriverProfilerSemverPattern = regexp.MustCompile(`^0\.(\d{8})\.(\d+)$`)

// Every file name that starts like a release must be a known release (YYYYMMDD_RCNN) or its alpine variant.
// Anything else is a format this watcher does not understand, and skipping it silently would hide new releases.
var stackdriverProfilerReleaseFilePattern = regexp.MustCompile(`java/cloud-profiler-java-agent_(\d{8}_RC\d+)\.tar\.gz$`)
var stackdriverProfilerAlpineFilePattern = regexp.MustCompile(`java/cloud-profiler-java-agent_\d{8}_RC\d+_alpine\.tar\.gz$`)

type gcsObjectsResponse struct {
	Items []gcsObject `json:"items"`
}

type gcsObject struct {
	Name    string `json:"name"`
	MD5Hash string `json:"md5Hash"`
}

// Google keeps an unversioned copy of the newest release here. Releases are only found by their dated file name,
// so when this copy has other content than the newest dated release, a release was published without one.
const stackdriverProfilerLatestObject = "java/latest/profiler_java_agent.tar.gz"

type StackdriverProfilerWatcher struct {
	client base.HTTPClient
}

// stackdriverProfilerVersion is a parsed Google release: the date and the release candidate number.
type stackdriverProfilerVersion struct {
	date      string
	candidate int
}

func (v stackdriverProfilerVersion) semver() string {
	return fmt.Sprintf("0.%s.%d", v.date, v.candidate)
}

func (v stackdriverProfilerVersion) artifactVersion() string {
	return fmt.Sprintf("%s_RC%02d", v.date, v.candidate)
}

func (v stackdriverProfilerVersion) before(other stackdriverProfilerVersion) bool {
	if v.date != other.date {
		return v.date < other.date
	}
	return v.candidate < other.candidate
}

// parseStackdriverProfilerVersion accepts the semver form (0.20261026.0) and the date form (20261026_RC00).
func parseStackdriverProfilerVersion(ref string) (stackdriverProfilerVersion, error) {
	m := stackdriverProfilerSemverPattern.FindStringSubmatch(ref)
	if m == nil {
		m = stackdriverProfilerArtifactVersionPattern.FindStringSubmatch(ref)
	}
	if m == nil {
		return stackdriverProfilerVersion{}, fmt.Errorf("unexpected Cloud Profiler agent version %q, expected 0.YYYYMMDD.N or YYYYMMDD_RCNN", ref)
	}

	candidate, err := strconv.Atoi(m[2])
	if err != nil {
		return stackdriverProfilerVersion{}, fmt.Errorf("unexpected Cloud Profiler agent version %q: %w", ref, err)
	}
	return stackdriverProfilerVersion{date: m[1], candidate: candidate}, nil
}

func NewStackdriverProfilerWatcher(client base.HTTPClient) *StackdriverProfilerWatcher {
	return &StackdriverProfilerWatcher{client: client}
}

func (w *StackdriverProfilerWatcher) Check() ([]base.Internal, error) {
	url := stackdriverProfilerBucket + "?prefix=java%2F&maxResults=1000&fields=items(name,md5Hash)"

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Cloud Profiler agent list: %w", err)
	}
	defer resp.Body.Close()

	var result gcsObjectsResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to parse Cloud Profiler agent list: %w", err)
	}

	var versions []stackdriverProfilerVersion
	md5ByVersion := map[stackdriverProfilerVersion]string{}
	fileByVersion := map[stackdriverProfilerVersion]string{}
	latestMD5, latestFound := "", false

	for _, item := range result.Items {
		if item.Name == stackdriverProfilerLatestObject {
			latestMD5, latestFound = item.MD5Hash, true
			continue
		}

		if m := stackdriverProfilerReleaseFilePattern.FindStringSubmatch(item.Name); m != nil {
			version, err := parseStackdriverProfilerVersion(m[1])
			if err != nil {
				return nil, err
			}
			versions = append(versions, version)
			md5ByVersion[version] = item.MD5Hash
			fileByVersion[version] = item.Name
			continue
		}

		isTarball := strings.HasPrefix(item.Name, "java/cloud-profiler-java-agent_") && strings.HasSuffix(item.Name, ".tar.gz")
		if isTarball && !stackdriverProfilerAlpineFilePattern.MatchString(item.Name) {
			return nil, fmt.Errorf("unexpected Cloud Profiler agent file name %q, expected cloud-profiler-java-agent_YYYYMMDD_RCNN.tar.gz", item.Name)
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no Cloud Profiler Java agent versions found")
	}

	sort.Slice(versions, func(i, j int) bool { return versions[i].before(versions[j]) })

	newest := versions[len(versions)-1]
	if !latestFound {
		return nil, fmt.Errorf("Cloud Profiler agent %q not found, cannot check that %q is the newest release", stackdriverProfilerLatestObject, fileByVersion[newest])
	}
	if latestMD5 != md5ByVersion[newest] {
		return nil, fmt.Errorf("Cloud Profiler agent %q differs from the newest dated release %q: a release was published without a dated file name", stackdriverProfilerLatestObject, fileByVersion[newest])
	}

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	result2 := make([]base.Internal, len(versions))
	for i, v := range versions {
		result2[i] = base.Internal{Ref: v.semver()}
	}

	return result2, nil
}

func (w *StackdriverProfilerWatcher) In(ref string) (base.Release, error) {
	version, err := parseStackdriverProfilerVersion(ref)
	if err != nil {
		return base.Release{}, err
	}

	url := fmt.Sprintf("%scloud-profiler-java-agent_%s.tar.gz", stackdriverProfilerDownloadBase, version.artifactVersion())

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download Cloud Profiler agent: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	return base.Release{
		Ref:    version.semver(),
		URL:    url,
		SHA256: fmt.Sprintf("%x", hash.Sum(nil)),
	}, nil
}
