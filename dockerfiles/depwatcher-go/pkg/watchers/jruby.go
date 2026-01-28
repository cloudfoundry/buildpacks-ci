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

type JRubyWatcher struct {
	client base.HTTPClient
}

func NewJRubyWatcher(client base.HTTPClient) *JRubyWatcher {
	return &JRubyWatcher{client: client}
}

func (w *JRubyWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://api.github.com/repos/jruby/jruby/releases?per_page=100")
	if err != nil {
		return nil, fmt.Errorf("fetching GitHub releases: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response body: %w", err)
	}

	var releases []githubRelease
	if err := json.Unmarshal(body, &releases); err != nil {
		return nil, fmt.Errorf("parsing JSON: %w", err)
	}

	var versions []base.Internal
	for _, release := range releases {
		if release.Prerelease {
			continue
		}

		tag := strings.TrimPrefix(release.TagName, "v")
		versions = append(versions, base.Internal{Ref: tag})
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no versions found in GitHub releases")
	}

	sort.Slice(versions, func(i, j int) bool {
		vi, err1 := semver.Parse(versions[i].Ref)
		vj, err2 := semver.Parse(versions[j].Ref)
		if err1 != nil || err2 != nil {
			return versions[i].Ref < versions[j].Ref
		}
		return vi.LessThan(vj)
	})

	return versions, nil
}

func (w *JRubyWatcher) In(ref string) (base.Release, error) {
	downloadURL, err := w.getDownloadURL(ref)
	if err != nil {
		return base.Release{}, err
	}

	sha256, err := base.GetSHA256(w.client, downloadURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("calculating SHA256: %w", err)
	}

	return base.Release{
		Ref:    ref,
		URL:    downloadURL,
		SHA256: sha256,
	}, nil
}

func (w *JRubyWatcher) getDownloadURL(ref string) (string, error) {
	resp, err := w.client.Get(fmt.Sprintf("https://api.github.com/repos/jruby/jruby/releases/tags/%s", ref))
	if err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		var release githubRelease
		if json.Unmarshal(body, &release) == nil {
			for _, asset := range release.Assets {
				if strings.Contains(asset.Name, "-src") && strings.HasSuffix(asset.Name, ".zip") {
					return asset.BrowserDownloadURL, nil
				}
			}
		}
	}

	return fmt.Sprintf("https://repo1.maven.org/maven2/org/jruby/jruby-dist/%s/jruby-dist-%s-src.zip", ref, ref), nil
}
