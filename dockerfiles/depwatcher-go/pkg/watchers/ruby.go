package watchers

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type RubyWatcher struct {
	client base.HTTPClient
}

type rubyGithubRelease struct {
	Version string            `yaml:"version"`
	URL     map[string]string `yaml:"url"`
	SHA256  map[string]string `yaml:"sha256"`
}

func NewRubyWatcher(client base.HTTPClient) *RubyWatcher {
	return &RubyWatcher{client: client}
}

func (w *RubyWatcher) Check() ([]base.Internal, error) {
	tagsWatcher := NewGithubTagsWatcher(w.client, "ruby/ruby")
	tags, err := tagsWatcher.MatchedTags(`^v\d+_\d+_\d+$`)
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, tag := range tags {
		ref := strings.ReplaceAll(tag.Name, "_", ".")
		ref = strings.TrimPrefix(ref, "v")
		internals = append(internals, base.Internal{Ref: ref})
	}

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

func (w *RubyWatcher) In(ref string) (base.Release, error) {
	release, err := w.releaseFromGithub(ref)
	if err == nil {
		return release, nil
	}

	return w.releaseFromIndex(ref)
}

func (w *RubyWatcher) releaseFromGithub(ref string) (base.Release, error) {
	resp, err := w.client.Get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml")
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching releases.yml: %w", err)
	}
	defer resp.Body.Close()

	var releases []rubyGithubRelease
	decoder := yaml.NewDecoder(resp.Body)
	if err := decoder.Decode(&releases); err != nil {
		return base.Release{}, fmt.Errorf("decoding releases.yml: %w", err)
	}

	for _, v := range releases {
		if v.Version == ref {
			url := v.URL["gz"]
			sha256 := v.SHA256["gz"]

			if url != "" && sha256 != "" {
				return base.Release{
					Ref:    v.Version,
					URL:    url,
					SHA256: sha256,
				}, nil
			}
		}
	}

	return base.Release{}, fmt.Errorf("release not found in releases.yml")
}

func (w *RubyWatcher) releaseFromIndex(ref string) (base.Release, error) {
	resp, err := w.client.Get("https://cache.ruby-lang.org/pub/ruby/index.txt")
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching index.txt: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("reading index.txt: %w", err)
	}

	lines := strings.Split(string(bodyBytes), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}

		version := strings.TrimPrefix(fields[0], "ruby-")
		url := fields[1]
		sha256 := fields[3]

		if version == ref && strings.HasSuffix(url, "tar.gz") {
			return base.Release{
				Ref:    version,
				URL:    url,
				SHA256: sha256,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("no release with ref: %s found", ref)
}
