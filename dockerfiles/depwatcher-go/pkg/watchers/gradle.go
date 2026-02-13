package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type GradleWatcher struct {
	client base.HTTPClient
}

type gradleReleasesResponse struct {
	FinalReleases []struct {
		Version string `json:"version"`
	} `json:"finalReleases"`
}

func NewGradleWatcher(client base.HTTPClient) *GradleWatcher {
	return &GradleWatcher{client: client}
}

func (w *GradleWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://raw.githubusercontent.com/gradle/gradle/master/released-versions.json")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Gradle releases: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code %d fetching Gradle releases", resp.StatusCode)
	}

	var releases gradleReleasesResponse
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("failed to decode Gradle releases: %w", err)
	}

	var internals []base.Internal
	for _, release := range releases.FinalReleases {
		internals = append(internals, base.Internal{Ref: release.Version})
	}

	// Sort versions
	sort.Slice(internals, func(i, j int) bool {
		vi, err1 := semver.Parse(internals[i].Ref)
		vj, err2 := semver.Parse(internals[j].Ref)
		if err1 != nil || err2 != nil {
			return internals[i].Ref < internals[j].Ref
		}
		return vi.LessThan(vj)
	})

	return internals, nil
}

func (w *GradleWatcher) In(ref string) (base.Release, error) {
	filename := fmt.Sprintf("gradle-%s-bin.zip", ref)
	url := fmt.Sprintf("https://downloads.gradle.org/distributions/%s", filename)

	// Fetch SHA256 from Gradle's checksums
	sha256URL := fmt.Sprintf("%s.sha256", url)
	resp, err := w.client.Get(sha256URL)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to fetch SHA256: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return base.Release{}, fmt.Errorf("unexpected status code %d fetching SHA256", resp.StatusCode)
	}

	sha256Bytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to read SHA256: %w", err)
	}

	// Trim whitespace/newlines from the hash
	sha256Hash := strings.TrimSpace(string(sha256Bytes))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256Hash,
	}, nil
}
