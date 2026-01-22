package watchers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path/filepath"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type LibericaWatcher struct {
	client  base.HTTPClient
	version string
	product string
	typ     string
	token   string
}

type libericaRelease struct {
	FeatureVersion int    `json:"featureVersion"`
	InterimVersion int    `json:"interimVersion"`
	UpdateVersion  int    `json:"updateVersion"`
	BuildVersion   int    `json:"buildVersion"`
	DownloadURL    string `json:"downloadUrl"`
}

func NewLibericaWatcher(client base.HTTPClient, version, product, typ, token string) *LibericaWatcher {
	return &LibericaWatcher{
		client:  client,
		version: version,
		product: product,
		typ:     typ,
		token:   token,
	}
}

func (w *LibericaWatcher) Check() ([]base.Internal, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return nil, err
	}

	var versions []base.Internal
	for _, r := range releases {
		version := fmt.Sprintf("%d.%d.%d+%d", r.FeatureVersion, r.InterimVersion, r.UpdateVersion, r.BuildVersion)
		versions = append(versions, base.Internal{Ref: version})
	}

	return w.sortVersions(versions), nil
}

func (w *LibericaWatcher) In(ref string) (base.Release, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return base.Release{}, err
	}

	for _, r := range releases {
		version := fmt.Sprintf("%d.%d.%d+%d", r.FeatureVersion, r.InterimVersion, r.UpdateVersion, r.BuildVersion)
		if version == ref {
			return base.Release{
				Ref: ref,
				URL: r.DownloadURL,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("could not find release for version %s", ref)
}

func (w *LibericaWatcher) fetchReleases() ([]libericaRelease, error) {
	if w.version == "" {
		return nil, fmt.Errorf("version must be specified")
	}
	if w.product == "" {
		return nil, fmt.Errorf("product must be specified")
	}
	if w.typ == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	apiURL := fmt.Sprintf("https://api.bell-sw.com/v1/liberica/releases?arch=x86&bitness=64&os=linux&package-type=tar.gz&version-modifier=latest&bundle-type=%s&version-feature=%s",
		w.typ, url.QueryEscape(w.version))

	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	// Add custom header if token is provided
	if w.token != "" {
		parts := strings.SplitN(w.token, " ", 2)
		if len(parts) == 2 {
			headerName := strings.TrimSuffix(strings.TrimSpace(parts[0]), ":")
			headerValue := strings.TrimSpace(parts[1])
			req.Header.Add(headerName, headerValue)
		}
	}

	resp, err := w.client.GetWithHeaders(apiURL, req.Header)
	if err != nil {
		return nil, fmt.Errorf("fetching releases: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var releases []libericaRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("decoding releases: %w", err)
	}

	return releases, nil
}

func (w *LibericaWatcher) sortVersions(internals []base.Internal) []base.Internal {
	sort.Slice(internals, func(i, j int) bool {
		// Liberica versions use '+' separator which semver handles
		vi, erri := semver.Parse(internals[i].Ref)
		vj, errj := semver.Parse(internals[j].Ref)
		if erri == nil && errj == nil {
			return vi.LessThan(vj)
		}
		return internals[i].Ref < internals[j].Ref
	})
	return internals
}

func (w *LibericaWatcher) name(uri string) string {
	return filepath.Base(uri)
}
