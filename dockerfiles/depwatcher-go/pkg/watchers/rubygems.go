package watchers

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type RubygemsWatcher struct {
	client base.HTTPClient
	name   string
}

type rubygemsMultiExternal struct {
	Number     string `json:"number"`
	Prerelease bool   `json:"prerelease"`
}

type rubygemsExternal struct {
	Number        string `json:"number"`
	SHA           string `json:"sha"`
	Prerelease    bool   `json:"prerelease"`
	SourceCodeURI string `json:"source_code_uri"`
}

func NewRubygemsWatcher(client base.HTTPClient, name string) *RubygemsWatcher {
	return &RubygemsWatcher{
		client: client,
		name:   name,
	}
}

// Check returns the last 10 non-prerelease versions of the specified RubyGem.
func (w *RubygemsWatcher) Check() ([]base.Internal, error) {
	releases, err := w.releases()
	if err != nil {
		return nil, err
	}

	// Filter out prereleases
	var stableReleases []rubygemsMultiExternal
	for _, r := range releases {
		if !r.Prerelease {
			stableReleases = append(stableReleases, r)
		}
	}

	// Sort by semver (descending - newest first)
	sort.Slice(stableReleases, func(i, j int) bool {
		vi, err1 := semver.Parse(stableReleases[i].Number)
		vj, err2 := semver.Parse(stableReleases[j].Number)
		if err1 != nil || err2 != nil {
			return stableReleases[i].Number > stableReleases[j].Number
		}
		return vj.LessThan(vi)
	})

	// Take last 10 and reverse (oldest to newest)
	count := len(stableReleases)
	if count > 10 {
		count = 10
	}

	result := make([]base.Internal, count)
	for i := 0; i < count; i++ {
		result[i] = base.Internal{Ref: stableReleases[count-1-i].Number}
	}

	return result, nil
}

// In returns detailed information about a specific RubyGem version.
func (w *RubygemsWatcher) In(version string) (base.Release, error) {
	external, err := w.release(version)
	if err != nil {
		return base.Release{}, err
	}

	return base.Release{
		Ref:    external.Number,
		SHA256: external.SHA,
		URL:    external.SourceCodeURI,
	}, nil
}

func (w *RubygemsWatcher) releases() ([]rubygemsMultiExternal, error) {
	url := fmt.Sprintf("https://rubygems.org/api/v1/versions/%s.json", w.name)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch rubygems versions: %w", err)
	}
	defer resp.Body.Close()

	var releases []rubygemsMultiExternal
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("failed to decode rubygems versions: %w", err)
	}

	return releases, nil
}

func (w *RubygemsWatcher) release(version string) (rubygemsExternal, error) {
	url := fmt.Sprintf("https://rubygems.org/api/v2/rubygems/%s/versions/%s.json", w.name, version)
	resp, err := w.client.Get(url)
	if err != nil {
		return rubygemsExternal{}, fmt.Errorf("failed to fetch rubygems version %s: %w", version, err)
	}
	defer resp.Body.Close()

	var external rubygemsExternal
	if err := json.NewDecoder(resp.Body).Decode(&external); err != nil {
		return rubygemsExternal{}, fmt.Errorf("failed to decode rubygems version %s: %w", version, err)
	}

	return external, nil
}
