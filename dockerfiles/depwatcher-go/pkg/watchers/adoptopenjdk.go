package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"path/filepath"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type AdoptOpenJDKWatcher struct {
	client         base.HTTPClient
	version        string
	implementation string
	jdkType        string
}

type adoptOpenJDKRelease struct {
	Binaries []struct {
		Package struct {
			Link string `json:"link"`
		} `json:"package"`
	} `json:"binaries"`
	VersionData struct {
		SemVer string `json:"semver"`
	} `json:"version_data"`
}

func NewAdoptOpenJDKWatcher(client base.HTTPClient, version, implementation, jdkType string) *AdoptOpenJDKWatcher {
	return &AdoptOpenJDKWatcher{
		client:         client,
		version:        version,
		implementation: implementation,
		jdkType:        jdkType,
	}
}

func (w *AdoptOpenJDKWatcher) Check() ([]base.Internal, error) {
	if w.version == "" {
		return nil, fmt.Errorf("version must be specified")
	}
	if w.implementation == "" {
		return nil, fmt.Errorf("implementation must be specified")
	}
	if w.jdkType == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	apiURL := w.buildAPIURL()

	resp, err := w.client.Get(apiURL)
	if err != nil {
		return nil, fmt.Errorf("fetching AdoptOpenJDK releases: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code %d fetching %s", resp.StatusCode, apiURL)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var releases []adoptOpenJDKRelease
	if err := json.Unmarshal(bodyBytes, &releases); err != nil {
		return nil, fmt.Errorf("parsing JSON response: %w", err)
	}

	var internals []base.Internal
	for _, release := range releases {
		if release.VersionData.SemVer != "" {
			internals = append(internals, base.Internal{Ref: release.VersionData.SemVer})
		}
	}

	internals = w.sortVersions(internals)

	return internals, nil
}

func (w *AdoptOpenJDKWatcher) In(ref string) (base.Release, error) {
	if w.version == "" {
		return base.Release{}, fmt.Errorf("version must be specified")
	}
	if w.implementation == "" {
		return base.Release{}, fmt.Errorf("implementation must be specified")
	}
	if w.jdkType == "" {
		return base.Release{}, fmt.Errorf("type must be specified")
	}

	apiURL := w.buildAPIURL()

	resp, err := w.client.Get(apiURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching AdoptOpenJDK releases: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return base.Release{}, fmt.Errorf("unexpected status code %d fetching %s", resp.StatusCode, apiURL)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("reading response: %w", err)
	}

	var releases []adoptOpenJDKRelease
	if err := json.Unmarshal(bodyBytes, &releases); err != nil {
		return base.Release{}, fmt.Errorf("parsing JSON response: %w", err)
	}

	for _, release := range releases {
		if release.VersionData.SemVer == ref && len(release.Binaries) > 0 {
			downloadURL := release.Binaries[0].Package.Link
			return base.Release{
				Ref: ref,
				URL: downloadURL,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("version %s not found in releases", ref)
}

func (w *AdoptOpenJDKWatcher) buildAPIURL() string {
	return fmt.Sprintf("https://api.adoptopenjdk.net/v3/assets/version/%s?architecture=x64&heap_size=normal&image_type=%s&jvm_impl=%s&os=linux&release_type=ga&vendor=adoptopenjdk",
		url.PathEscape(w.version), w.jdkType, w.implementation)
}

func (w *AdoptOpenJDKWatcher) sortVersions(internals []base.Internal) []base.Internal {
	sorted := make([]base.Internal, len(internals))
	copy(sorted, internals)

	for i := 0; i < len(sorted)-1; i++ {
		for j := i + 1; j < len(sorted); j++ {
			vi, err1 := semver.Parse(sorted[i].Ref)
			vj, err2 := semver.Parse(sorted[j].Ref)
			if err1 != nil || err2 != nil {
				if sorted[i].Ref > sorted[j].Ref {
					sorted[i], sorted[j] = sorted[j], sorted[i]
				}
			} else if vj.LessThan(vi) {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}

	return sorted
}

func GetFilenameFromURL(downloadURL string) string {
	return filepath.Base(downloadURL)
}
