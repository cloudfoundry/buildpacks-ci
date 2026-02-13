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

func NewLibericaWatcher(client base.HTTPClient, version, typ, token string) *LibericaWatcher {
	return &LibericaWatcher{
		client:  client,
		version: version,
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
	if w.typ == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	var apiURL string
	if w.version == "" {
		// No version specified - get all releases and we'll filter to latest per major version
		apiURL = fmt.Sprintf("https://api.bell-sw.com/v1/liberica/releases?arch=x86&bitness=64&os=linux&package-type=tar.gz&bundle-type=%s",
			w.typ)
	} else {
		apiURL = fmt.Sprintf("https://api.bell-sw.com/v1/liberica/releases?arch=x86&bitness=64&os=linux&package-type=tar.gz&version-modifier=latest&bundle-type=%s&version-feature=%s",
			w.typ, url.QueryEscape(w.version))
	}

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

	if w.version == "" {
		// When no version is specified, filter to get only the latest for each major version
		return w.filterLatestPerMajorVersion(releases), nil
	}

	return releases, nil
}

func (w *LibericaWatcher) filterLatestPerMajorVersion(releases []libericaRelease) []libericaRelease {
	// Group by major version (featureVersion)
	versionMap := make(map[int]libericaRelease)

	for _, release := range releases {
		existing, exists := versionMap[release.FeatureVersion]
		if !exists {
			versionMap[release.FeatureVersion] = release
		} else {
			// Keep the latest version for each major version
			if w.isNewerRelease(release, existing) {
				versionMap[release.FeatureVersion] = release
			}
		}
	}

	// Convert map back to slice
	var filtered []libericaRelease
	for _, release := range versionMap {
		filtered = append(filtered, release)
	}

	return filtered
}

func (w *LibericaWatcher) isNewerRelease(r1, r2 libericaRelease) bool {
	if r1.InterimVersion != r2.InterimVersion {
		return r1.InterimVersion > r2.InterimVersion
	}
	if r1.UpdateVersion != r2.UpdateVersion {
		return r1.UpdateVersion > r2.UpdateVersion
	}
	return r1.BuildVersion > r2.BuildVersion
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
