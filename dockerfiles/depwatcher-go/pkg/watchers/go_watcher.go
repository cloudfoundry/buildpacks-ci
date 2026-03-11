package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type GoWatcher struct {
	client base.HTTPClient
}

type goVersionJSON struct {
	Version string       `json:"version"`
	Stable  bool         `json:"stable"`
	Files   []goFileJSON `json:"files"`
}

type goFileJSON struct {
	Filename string `json:"filename"`
	OS       string `json:"os"`
	Arch     string `json:"arch"`
	Version  string `json:"version"`
	SHA256   string `json:"sha256"`
	Size     int64  `json:"size"`
	Kind     string `json:"kind"`
}

func NewGoWatcher(client base.HTTPClient) *GoWatcher {
	return &GoWatcher{client: client}
}

func (w *GoWatcher) Check() ([]base.Internal, error) {
	releases, err := w.getReleases()
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, r := range releases {
		internals = append(internals, base.Internal{Ref: r.Ref})
	}

	return base.SortVersions(internals), nil
}

func (w *GoWatcher) In(ref string) (base.Release, error) {
	releases, err := w.getReleases()
	if err != nil {
		return base.Release{}, err
	}

	for _, r := range releases {
		if r.Ref == ref {
			return r, nil
		}
	}

	return base.Release{}, fmt.Errorf("could not find data for version %s", ref)
}

func (w *GoWatcher) getReleases() ([]base.Release, error) {
	resp, err := w.client.Get("https://go.dev/dl/?mode=json&include=all")
	if err != nil {
		return nil, fmt.Errorf("fetching go.dev/dl JSON: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var versions []goVersionJSON
	if err := json.Unmarshal(body, &versions); err != nil {
		return nil, fmt.Errorf("parsing JSON: %w", err)
	}

	var releases []base.Release
	for _, v := range versions {
		if !v.Stable {
			continue
		}

		version := strings.TrimPrefix(v.Version, "go")

		var sourceFile *goFileJSON
		for _, f := range v.Files {
			if f.Kind == "source" && strings.HasSuffix(f.Filename, ".src.tar.gz") {
				sourceFile = &f
				break
			}
		}

		if sourceFile == nil {
			continue
		}

		url := fmt.Sprintf("https://dl.google.com/go/%s", sourceFile.Filename)

		releases = append(releases, base.Release{
			Ref:    version,
			URL:    url,
			SHA256: strings.TrimSpace(sourceFile.SHA256),
		})
	}

	return releases, nil
}
