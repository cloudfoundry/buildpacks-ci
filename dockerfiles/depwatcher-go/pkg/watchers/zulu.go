package watchers

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type ZuluWatcher struct {
	client  base.HTTPClient
	version string
	typ     string
}

type zuluRelease struct {
	JDKVersion []int  `json:"jdk_version"`
	URL        string `json:"url"`
}

func NewZuluWatcher(client base.HTTPClient, version, typ string) *ZuluWatcher {
	return &ZuluWatcher{
		client:  client,
		version: version,
		typ:     typ,
	}
}

func (w *ZuluWatcher) Check() ([]base.Internal, error) {
	release, err := w.fetchRelease()
	if err != nil {
		return nil, err
	}

	version, err := w.parseVersion(release.JDKVersion)
	if err != nil {
		return nil, err
	}

	return []base.Internal{{Ref: version}}, nil
}

func (w *ZuluWatcher) In(ref string) (base.Release, error) {
	release, err := w.fetchRelease()
	if err != nil {
		return base.Release{}, err
	}

	version, err := w.parseVersion(release.JDKVersion)
	if err != nil {
		return base.Release{}, err
	}

	if version != ref {
		return base.Release{}, fmt.Errorf("version mismatch: expected %s, got %s", ref, version)
	}

	return base.Release{
		Ref: ref,
		URL: release.URL,
	}, nil
}

func (w *ZuluWatcher) fetchRelease() (*zuluRelease, error) {
	if w.version == "" {
		return nil, fmt.Errorf("version must be specified")
	}
	if w.typ == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	url := fmt.Sprintf("https://api.azul.com/zulu/download/azure-only/v1.0/bundles/latest/?arch=x86&ext=tar.gz&features=%s&hw_bitness=64&jdk_version=%s&os=linux",
		w.typ, w.version)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching release: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var release zuluRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, fmt.Errorf("decoding release: %w", err)
	}

	return &release, nil
}

func (w *ZuluWatcher) parseVersion(versionParts []int) (string, error) {
	if len(versionParts) != 3 {
		return "", fmt.Errorf("version must have three components: got %d", len(versionParts))
	}
	return fmt.Sprintf("%d.%d.%d", versionParts[0], versionParts[1], versionParts[2]), nil
}

func (w *ZuluWatcher) sortVersions(internals []base.Internal) []base.Internal {
	sort.Slice(internals, func(i, j int) bool {
		vi, erri := semver.Parse(internals[i].Ref)
		vj, errj := semver.Parse(internals[j].Ref)
		if erri == nil && errj == nil {
			return vi.LessThan(vj)
		}
		return internals[i].Ref < internals[j].Ref
	})
	return internals
}

func (w *ZuluWatcher) name(uri string) string {
	return filepath.Base(uri)
}
