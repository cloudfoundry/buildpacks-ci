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

// In returns the download URL and source SHA256 for a specific RubyGems CLI version.
func (w *RubygemsCLIWatcher) In(version string) (base.Release, error) {
	url := fmt.Sprintf("https://rubygems.org/rubygems/rubygems-%s.tgz", version)

	sha256, err := base.GetSHA256(w.client, url)
	if err != nil {
		return base.Release{}, fmt.Errorf("calculating SHA256 for rubygems %s: %w", version, err)
	}

	return base.Release{
		Ref:    version,
		URL:    url,
		SHA256: sha256,
	}, nil
}
