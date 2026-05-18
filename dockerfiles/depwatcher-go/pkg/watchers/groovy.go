package watchers

import (
	"encoding/json"
	"fmt"
	"regexp"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const groovyStorageBase = "https://groovy.jfrog.io/artifactory/api/storage/dist-release-local/groovy-zips"
const groovyDownloadBase = "https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips"

type groovyChild struct {
	URI    string `json:"uri"`
	Folder bool   `json:"folder"`
}

type groovyDirResponse struct {
	Children []groovyChild `json:"children"`
}

type groovyFileResponse struct {
	Checksums struct {
		SHA256 string `json:"sha256"`
	} `json:"checksums"`
	DownloadURI string `json:"downloadUri"`
}

type GroovyWatcher struct {
	client base.HTTPClient
}

func NewGroovyWatcher(client base.HTTPClient) *GroovyWatcher {
	return &GroovyWatcher{client: client}
}

// stable release: apache-groovy-binary-X.Y.Z.zip (no alpha/beta/rc suffix)
var groovyVersionPattern = regexp.MustCompile(`^/apache-groovy-binary-(\d+\.\d+\.\d+)\.zip$`)

func (w *GroovyWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get(groovyStorageBase + "/")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Groovy file list: %w", err)
	}
	defer resp.Body.Close()

	var dir groovyDirResponse
	if err := json.NewDecoder(resp.Body).Decode(&dir); err != nil {
		return nil, fmt.Errorf("failed to parse Groovy file list: %w", err)
	}

	var versions []base.Internal
	for _, child := range dir.Children {
		if child.Folder {
			continue
		}
		if m := groovyVersionPattern.FindStringSubmatch(child.URI); m != nil {
			versions = append(versions, base.Internal{Ref: m[1]})
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no Groovy versions found in file list")
	}

	versions = base.SortVersions(versions)

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

func (w *GroovyWatcher) In(ref string) (base.Release, error) {
	metaURL := fmt.Sprintf("%s/apache-groovy-binary-%s.zip", groovyStorageBase, ref)

	resp, err := w.client.Get(metaURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to fetch Groovy metadata: %w", err)
	}
	defer resp.Body.Close()

	var meta groovyFileResponse
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		return base.Release{}, fmt.Errorf("failed to parse Groovy metadata: %w", err)
	}

	if meta.Checksums.SHA256 == "" {
		return base.Release{}, fmt.Errorf("no SHA256 found in Groovy metadata for %s", ref)
	}

	return base.Release{
		Ref:    ref,
		URL:    fmt.Sprintf("%s/apache-groovy-binary-%s.zip", groovyDownloadBase, ref),
		SHA256: meta.Checksums.SHA256,
	}, nil
}
