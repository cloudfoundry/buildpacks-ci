package watchers

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type NPMWatcher struct {
	client base.HTTPClient
}

type npmDist struct {
	Shasum  string `json:"shasum"`
	Tarball string `json:"tarball"`
}

type npmVersion struct {
	Name    string  `json:"name"`
	Version string  `json:"version"`
	Dist    npmDist `json:"dist"`
}

type npmRegistry struct {
	Versions map[string]npmVersion `json:"versions"`
}

func NewNPMWatcher(client base.HTTPClient) *NPMWatcher {
	return &NPMWatcher{client: client}
}

func (w *NPMWatcher) Check(packageName string) ([]base.Internal, error) {
	versions, err := w.getVersions(packageName)
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for version := range versions {
		internals = append(internals, base.Internal{Ref: version})
	}

	internals = base.SortVersions(internals)

	if len(internals) > 10 {
		return internals[len(internals)-10:], nil
	}

	return internals, nil
}

func (w *NPMWatcher) In(packageName, ref string) (base.Release, error) {
	versions, err := w.getVersions(packageName)
	if err != nil {
		return base.Release{}, err
	}

	version, ok := versions[ref]
	if !ok {
		return base.Release{}, fmt.Errorf("version %s not found for package %s", ref, packageName)
	}

	return base.Release{
		Ref:  ref,
		URL:  version.Dist.Tarball,
		SHA1: version.Dist.Shasum,
	}, nil
}

func (w *NPMWatcher) getVersions(packageName string) (map[string]npmVersion, error) {
	url := fmt.Sprintf("https://registry.npmjs.com/%s/", packageName)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching npm registry: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var registry npmRegistry
	if err := json.Unmarshal(bodyBytes, &registry); err != nil {
		return nil, fmt.Errorf("decoding JSON: %w", err)
	}

	return registry.Versions, nil
}
