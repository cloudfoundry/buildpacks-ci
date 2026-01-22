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

type NodeWatcher struct {
	client base.HTTPClient
}

type nodeRelease struct {
	Version  string   `json:"version"`
	Date     string   `json:"date"`
	Files    []string `json:"files"`
	Npm      string   `json:"npm"`
	V8       string   `json:"v8"`
	Uv       string   `json:"uv"`
	Zlib     string   `json:"zlib"`
	Openssl  string   `json:"openssl"`
	Modules  string   `json:"modules"`
	Lts      any      `json:"lts"`
	Security bool     `json:"security"`
}

func NewNodeWatcher(client base.HTTPClient) *NodeWatcher {
	return &NodeWatcher{client: client}
}

func (w *NodeWatcher) Check() ([]base.Internal, error) {
	versions, err := w.versionNumbers()
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, v := range versions {
		internals = append(internals, base.Internal{Ref: v})
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

func (w *NodeWatcher) In(ref string) (base.Release, error) {
	url := w.url(ref)
	sha256, err := w.shasum256(ref)
	if err != nil {
		return base.Release{}, err
	}

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256,
	}, nil
}

func (w *NodeWatcher) url(version string) string {
	return fmt.Sprintf("https://nodejs.org/dist/v%s/node-v%s.tar.gz", version, version)
}

func (w *NodeWatcher) shasum256(version string) (string, error) {
	url := fmt.Sprintf("https://nodejs.org/dist/v%s/SHASUMS256.txt", version)
	resp, err := w.client.Get(url)
	if err != nil {
		return "", fmt.Errorf("fetching SHASUMS256.txt: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("reading SHASUMS256.txt: %w", err)
	}

	filename := fmt.Sprintf("node-v%s.tar.gz", version)
	lines := strings.Split(string(bodyBytes), "\n")
	for _, line := range lines {
		if strings.HasSuffix(strings.TrimSpace(line), filename) {
			parts := strings.Fields(line)
			if len(parts) >= 1 {
				return parts[0], nil
			}
		}
	}

	return "", fmt.Errorf("could not find SHA256 for %s", filename)
}

func (w *NodeWatcher) versionNumbers() ([]string, error) {
	resp, err := w.client.Get("https://nodejs.org/dist/index.json")
	if err != nil {
		return nil, fmt.Errorf("fetching node releases: %w", err)
	}
	defer resp.Body.Close()

	var releases []nodeRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("decoding node releases: %w", err)
	}

	var versions []string
	for _, release := range releases {
		version := strings.TrimPrefix(release.Version, "v")
		ver, err := semver.Parse(version)
		if err != nil {
			continue
		}

		if ver.Major%2 == 0 && ver.Major >= 12 {
			versions = append(versions, version)
		}
	}

	return versions, nil
}
