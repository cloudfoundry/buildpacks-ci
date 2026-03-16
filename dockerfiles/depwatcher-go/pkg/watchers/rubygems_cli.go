package watchers

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type RubygemsCLIWatcher struct {
	client base.HTTPClient
}

type rubygemsAPIVersion struct {
	Number     string `json:"number"`
	Prerelease bool   `json:"prerelease"`
}

func NewRubygemsCLIWatcher(client base.HTTPClient) *RubygemsCLIWatcher {
	return &RubygemsCLIWatcher{client: client}
}

func (w *RubygemsCLIWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://rubygems.org/api/v1/versions/rubygems-update.json")
	if err != nil {
		return nil, fmt.Errorf("fetching rubygems API: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response body: %w", err)
	}

	var releases []rubygemsAPIVersion
	if err := json.Unmarshal(body, &releases); err != nil {
		return nil, fmt.Errorf("parsing JSON: %w", err)
	}

	var versions []base.Internal
	for _, release := range releases {
		if release.Prerelease {
			continue
		}
		versions = append(versions, base.Internal{Ref: release.Number})
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no versions found in API response")
	}

	versions = base.SortVersions(versions)

	// Return only the last 10 versions (most recent)
	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

// In returns the download URL for a specific RubyGems CLI version.
func (w *RubygemsCLIWatcher) In(version string) (base.Release, error) {
	return base.Release{
		Ref: version,
		URL: fmt.Sprintf("https://rubygems.org/rubygems/rubygems-%s.tgz", version),
	}, nil
}
