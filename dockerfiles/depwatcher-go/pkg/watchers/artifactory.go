package watchers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type ArtifactoryWatcher struct {
	client          base.HTTPClient
	uri             string
	groupID         string
	artifactID      string
	repository      string
	artifactPattern *regexp.Regexp
	username        string
	password        string
}

type artifactorySearchResult struct {
	Results []struct {
		DownloadURI string `json:"downloadUri"`
		Path        string `json:"path"`
	} `json:"results"`
}

func NewArtifactoryWatcher(client base.HTTPClient, uri, groupID, artifactID, repository, artifactPattern, username, password string) (*ArtifactoryWatcher, error) {
	var pattern *regexp.Regexp
	var err error

	if artifactPattern != "" {
		pattern, err = regexp.Compile(artifactPattern)
		if err != nil {
			return nil, fmt.Errorf("invalid artifact pattern: %w", err)
		}
	}

	return &ArtifactoryWatcher{
		client:          client,
		uri:             uri,
		groupID:         groupID,
		artifactID:      artifactID,
		repository:      repository,
		artifactPattern: pattern,
		username:        username,
		password:        password,
	}, nil
}

func (w *ArtifactoryWatcher) Check() ([]base.Internal, error) {
	results, err := w.search()
	if err != nil {
		return nil, err
	}

	versionPattern := regexp.MustCompile(`^.+/([\d]+)\.([\d]+)\.([\d]+)[.-]?(.*)/[^/]+$`)
	versionMap := make(map[string]string)

	for _, r := range results.Results {
		// Apply artifact pattern filter if specified
		if w.artifactPattern != nil && !w.artifactPattern.MatchString(r.Path) {
			continue
		}

		matches := versionPattern.FindStringSubmatch(r.Path)
		if matches == nil || len(matches) < 4 {
			continue
		}

		version := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
		if matches[4] != "" {
			version = fmt.Sprintf("%s-%s", version, matches[4])
		}

		versionMap[version] = r.DownloadURI
	}

	var versions []base.Internal
	for v := range versionMap {
		versions = append(versions, base.Internal{Ref: v})
	}

	return w.sortVersions(versions), nil
}

func (w *ArtifactoryWatcher) In(ref string) (base.Release, error) {
	results, err := w.search()
	if err != nil {
		return base.Release{}, err
	}

	versionPattern := regexp.MustCompile(`^.+/([\d]+)\.([\d]+)\.([\d]+)[.-]?(.*)/[^/]+$`)

	for _, r := range results.Results {
		if w.artifactPattern != nil && !w.artifactPattern.MatchString(r.Path) {
			continue
		}

		matches := versionPattern.FindStringSubmatch(r.Path)
		if matches == nil || len(matches) < 4 {
			continue
		}

		version := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
		if matches[4] != "" {
			version = fmt.Sprintf("%s-%s", version, matches[4])
		}

		if version == ref {
			return base.Release{
				Ref: ref,
				URL: r.DownloadURI,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("could not find version %s", ref)
}

func (w *ArtifactoryWatcher) search() (*artifactorySearchResult, error) {
	if w.uri == "" {
		return nil, fmt.Errorf("uri must be specified")
	}
	if w.groupID == "" {
		return nil, fmt.Errorf("group_id must be specified")
	}
	if w.artifactID == "" {
		return nil, fmt.Errorf("artifact_id must be specified")
	}
	if w.repository == "" {
		return nil, fmt.Errorf("repository must be specified")
	}

	// Build URL with properly escaped query parameters
	baseURL := fmt.Sprintf("%s/api/search/gavc", w.uri)
	params := url.Values{}
	params.Set("g", w.groupID)
	params.Set("a", w.artifactID)
	params.Set("repos", w.repository)
	searchURL := fmt.Sprintf("%s?%s", baseURL, params.Encode())

	req, err := http.NewRequest("GET", searchURL, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("X-Result-Detail", "info")

	// Add authentication if provided
	if w.username != "" && w.password != "" {
		req.SetBasicAuth(w.username, w.password)
	}

	resp, err := w.client.GetWithHeaders(searchURL, req.Header)
	if err != nil {
		return nil, fmt.Errorf("searching artifactory: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var results artifactorySearchResult
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, fmt.Errorf("decoding search results: %w", err)
	}

	return &results, nil
}

func (w *ArtifactoryWatcher) sortVersions(internals []base.Internal) []base.Internal {
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

func (w *ArtifactoryWatcher) name(uri string) string {
	return path.Base(uri)
}
