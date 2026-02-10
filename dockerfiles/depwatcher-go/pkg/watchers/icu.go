package watchers

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type ICUWatcher struct {
	client base.HTTPClient
}

func NewICUWatcher(client base.HTTPClient) *ICUWatcher {
	return &ICUWatcher{client: client}
}

type icuRelease struct {
	TagName    string `json:"tag_name"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
}

// Check retrieves all non-prerelease ICU versions from GitHub releases.
// Transforms tag names (e.g., release-65-1) to semantic versions (65.1.0).
// Returns versions sorted by semver, limited to last 10.
func (w *ICUWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://api.github.com/repos/unicode-org/icu/releases")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch ICU releases: %w", err)
	}
	defer resp.Body.Close()

	var releases []icuRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("failed to decode ICU releases: %w", err)
	}

	var versions []base.Internal
	for _, release := range releases {
		if release.Draft || release.Prerelease {
			continue
		}

		version := transformICUVersion(release.TagName)
		if version == "" {
			continue
		}

		versions = append(versions, base.Internal{Ref: version})
	}

	sort.Slice(versions, func(i, j int) bool {
		vi, err1 := semver.Parse(versions[i].Ref)
		vj, err2 := semver.Parse(versions[j].Ref)
		if err1 != nil || err2 != nil {
			return versions[i].Ref < versions[j].Ref
		}
		return vi.LessThan(vj)
	})

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

// In fetches the ICU source tarball metadata for a specific version and computes its SHA256.
func (w *ICUWatcher) In(version string) (base.Release, error) {
	tag := reverseTransformICUVersion(version)

	parts := strings.Split(version, ".")
	majorNum := 0
	if len(parts) > 0 {
		fmt.Sscanf(parts[0], "%d", &majorNum)
	}

	var filenameVersion, extension string
	if majorNum >= 78 {
		filenameVersion = version
		if strings.HasSuffix(filenameVersion, ".0") {
			filenameVersion = strings.TrimSuffix(filenameVersion, ".0")
		}
		extension = "sources.tgz"
	} else {
		filenameVersion = strings.ReplaceAll(strings.TrimPrefix(tag, "release-"), "-", "_")
		extension = "src.tgz"
	}

	filename := fmt.Sprintf("icu4c-%s-%s", filenameVersion, extension)
	url := fmt.Sprintf("https://github.com/unicode-org/icu/releases/download/%s/%s", tag, filename)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download ICU tarball: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	_, err = io.Copy(hash, resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    version,
		URL:    url,
		SHA256: sha256sum,
	}, nil
}

func transformICUVersion(tagName string) string {
	tagName = strings.TrimPrefix(tagName, "release-")
	version := strings.ReplaceAll(tagName, "-", ".")

	matched, _ := regexp.MatchString(`^\d+\.\d+$`, version)
	if matched {
		version += ".0"
	}

	return version
}

func reverseTransformICUVersion(version string) string {
	parts := strings.Split(version, ".")
	if len(parts) < 2 {
		return "release-" + version
	}

	major := parts[0]
	if len(parts) == 3 && parts[2] == "0" {
		version = major + "." + parts[1]
	}

	majorNum := 0
	fmt.Sscanf(major, "%d", &majorNum)

	if majorNum >= 78 {
		return "release-" + version
	}

	tag := strings.ReplaceAll(version, ".", "-")
	return "release-" + tag
}
