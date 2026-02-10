package watchers

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type CaApmAgentWatcher struct {
	client base.HTTPClient
}

type artifactoryChild struct {
	URI    string `json:"uri"`
	Folder bool   `json:"folder"`
}

type artifactoryResponse struct {
	Children []artifactoryChild `json:"children"`
}

func NewCaApmAgentWatcher(client base.HTTPClient) *CaApmAgentWatcher {
	return &CaApmAgentWatcher{client: client}
}

func (w *CaApmAgentWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://packages.broadcom.com/artifactory/api/storage/apm-agents/")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Artifactory API: %w", err)
	}
	defer resp.Body.Close()

	var apiResp artifactoryResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, fmt.Errorf("failed to parse Artifactory JSON: %w", err)
	}

	pattern := regexp.MustCompile(`^/CA-APM-PHPAgent-([\d\.]+)_linux\.tar\.gz$`)
	var versions []string

	for _, child := range apiResp.Children {
		if child.Folder {
			continue
		}

		matches := pattern.FindStringSubmatch(child.URI)
		if len(matches) > 1 {
			versions = append(versions, matches[1])
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no CA APM PHP agent versions found in API response")
	}

	result := make([]base.Internal, len(versions))
	for i, version := range versions {
		result[i] = base.Internal{Ref: version}
	}

	sort.Slice(result, func(i, j int) bool {
		vi, err1 := semver.Parse(result[i].Ref)
		vj, err2 := semver.Parse(result[j].Ref)
		if err1 != nil || err2 != nil {
			return result[i].Ref < result[j].Ref
		}
		return vi.LessThan(vj)
	})

	if len(result) > 10 {
		result = result[len(result)-10:]
	}

	return result, nil
}

func (w *CaApmAgentWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-%s_linux.tar.gz", ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download CA APM agent: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256sum,
	}, nil
}
