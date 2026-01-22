package watchers

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type PyPIWatcher struct {
	client base.HTTPClient
}

type pypiResponse struct {
	Releases map[string][]pypiRelease `json:"releases"`
}

type pypiRelease struct {
	URL         string            `json:"url"`
	Digests     map[string]string `json:"digests"`
	MD5Digest   string            `json:"md5_digest"`
	PackageType string            `json:"packagetype"`
	Size        int64             `json:"size"`
}

func NewPyPIWatcher(client base.HTTPClient) *PyPIWatcher {
	return &PyPIWatcher{client: client}
}

// Check fetches all available versions of a PyPI package
func (w *PyPIWatcher) Check(packageName string) ([]base.Internal, error) {
	url := fmt.Sprintf("https://pypi.org/pypi/%s/json", packageName)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching pypi package %s: %w", packageName, err)
	}
	defer resp.Body.Close()

	var data pypiResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("parsing pypi response: %w", err)
	}

	var versions []base.Internal
	for version := range data.Releases {
		ver, err := semver.Parse(version)
		if err != nil {
			continue
		}
		if ver.IsFinalRelease() {
			versions = append(versions, base.Internal{Ref: version})
		}
	}

	sort.Slice(versions, func(i, j int) bool {
		vi, err1 := semver.Parse(versions[i].Ref)
		vj, err2 := semver.Parse(versions[j].Ref)
		if err1 != nil || err2 != nil {
			return versions[i].Ref < versions[j].Ref
		}
		return vi.LessThan(vj)
	})

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

// In fetches detailed information about a specific PyPI package version
func (w *PyPIWatcher) In(packageName, ref string) (base.Release, error) {
	url := fmt.Sprintf("https://pypi.org/pypi/%s/json", packageName)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching pypi package %s: %w", packageName, err)
	}
	defer resp.Body.Close()

	var data pypiResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return base.Release{}, fmt.Errorf("parsing pypi response: %w", err)
	}

	releases, ok := data.Releases[ref]
	if !ok {
		return base.Release{}, fmt.Errorf("version %s not found for package %s", ref, packageName)
	}

	var sdists []pypiRelease
	for _, release := range releases {
		if release.PackageType == "sdist" {
			sdists = append(sdists, release)
		}
	}

	if len(sdists) == 0 {
		return base.Release{}, fmt.Errorf("no sdist found for %s version %s", packageName, ref)
	}

	sort.Slice(sdists, func(i, j int) bool {
		return sdists[i].Size < sdists[j].Size
	})

	sdist := sdists[0]
	sha256 := sdist.Digests["sha256"]

	return base.Release{
		Ref:    ref,
		URL:    sdist.URL,
		MD5:    sdist.MD5Digest,
		SHA256: sha256,
	}, nil
}
