package watchers

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type CorrettoWatcher struct {
	client     base.HTTPClient
	owner      string
	repository string
}

type correttoRelease struct {
	TagName    string `json:"tag_name"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
}

func NewCorrettoWatcher(client base.HTTPClient, owner, repository string) *CorrettoWatcher {
	return &CorrettoWatcher{
		client:     client,
		owner:      owner,
		repository: repository,
	}
}

func (w *CorrettoWatcher) Check() ([]base.Internal, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return nil, err
	}

	pattern := regexp.MustCompile(`([\d]+)\.([\d]+)\.([\d]+)\.([^-]+)`)
	var versions []base.Internal

	for _, release := range releases {
		if release.Draft || release.Prerelease {
			continue
		}

		matches := pattern.FindStringSubmatch(release.TagName)
		if matches == nil || len(matches) < 5 {
			continue
		}

		version := fmt.Sprintf("%s.%s.%s-%s", matches[1], matches[2], matches[3], matches[4])
		versions = append(versions, base.Internal{Ref: version})
	}

	return w.sortVersions(versions), nil
}

func (w *CorrettoWatcher) In(ref string) (base.Release, error) {
	// Convert version from "8.0.302-1" format to "8.0.302.1" for URL
	urlVersion := strings.Replace(ref, "-", ".", 1)
	name := fmt.Sprintf("amazon-corretto-%s-linux-x64.tar.gz", urlVersion)
	url := fmt.Sprintf("https://corretto.aws/downloads/resources/%s/%s", urlVersion, name)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}

func (w *CorrettoWatcher) fetchReleases() ([]correttoRelease, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases", w.owner, w.repository)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching releases: %w", err)
	}
	defer resp.Body.Close()

	var releases []correttoRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("decoding releases: %w", err)
	}

	return releases, nil
}

func (w *CorrettoWatcher) sortVersions(internals []base.Internal) []base.Internal {
	sort.Slice(internals, func(i, j int) bool {
		// Try semver comparison first
		vi, erri := semver.Parse(internals[i].Ref)
		vj, errj := semver.Parse(internals[j].Ref)
		if erri == nil && errj == nil {
			return vi.LessThan(vj)
		}
		// Fallback to string comparison
		return internals[i].Ref < internals[j].Ref
	})
	return internals
}
