package watchers

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const stackdriverProfilerBucket = "https://storage.googleapis.com/storage/v1/b/cloud-profiler/o"
const stackdriverProfilerDownloadBase = "https://storage.googleapis.com/cloud-profiler/java/"

type gcsObjectsResponse struct {
	Items []gcsObject `json:"items"`
}

type gcsObject struct {
	Name string `json:"name"`
}

type StackdriverProfilerWatcher struct {
	client base.HTTPClient
}

func NewStackdriverProfilerWatcher(client base.HTTPClient) *StackdriverProfilerWatcher {
	return &StackdriverProfilerWatcher{client: client}
}

func (w *StackdriverProfilerWatcher) Check() ([]base.Internal, error) {
	url := stackdriverProfilerBucket + "?prefix=java%2Fcloud-profiler-java-agent_&maxResults=1000"

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Cloud Profiler agent list: %w", err)
	}
	defer resp.Body.Close()

	var result gcsObjectsResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to parse Cloud Profiler agent list: %w", err)
	}

	// Match non-alpine tarballs: cloud-profiler-java-agent_YYYYMMDD_RCNN.tar.gz
	pattern := regexp.MustCompile(`java/cloud-profiler-java-agent_(\d{8}_RC\d+)\.tar\.gz$`)
	var versions []string

	for _, item := range result.Items {
		if m := pattern.FindStringSubmatch(item.Name); m != nil {
			versions = append(versions, m[1])
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no Cloud Profiler Java agent versions found")
	}

	// YYYYMMDD_RCNN sorts correctly lexicographically
	sort.Strings(versions)

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	result2 := make([]base.Internal, len(versions))
	for i, v := range versions {
		result2[i] = base.Internal{Ref: v}
	}

	return result2, nil
}

func (w *StackdriverProfilerWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("%scloud-profiler-java-agent_%s.tar.gz", stackdriverProfilerDownloadBase, ref)

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
		Ref:    ref,
		URL:    url,
		SHA256: fmt.Sprintf("%x", hash.Sum(nil)),
	}, nil
}
