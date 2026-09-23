package watchers

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

// YarnBerryWatcher discovers and fetches Yarn Berry (2.x/3.x/4.x) releases.
//
// Yarn Berry is not published as GitHub Release assets or as a self-contained
// npm package - it is distributed exclusively via Yarn's own release registry
// at https://repo.yarnpkg.com, which is the same source Corepack itself uses
// to resolve and fetch a given Yarn version.
type YarnBerryWatcher struct {
	client base.HTTPClient
}

func NewYarnBerryWatcher(client base.HTTPClient) *YarnBerryWatcher {
	return &YarnBerryWatcher{client: client}
}

type yarnBerryTags struct {
	Tags []string `json:"tags"`
}

// Check fetches all available Yarn Berry versions from repo.yarnpkg.com.
func (w *YarnBerryWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://repo.yarnpkg.com/tags")
	if err != nil {
		return nil, fmt.Errorf("fetching yarn berry tags: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var tags yarnBerryTags
	if err := json.Unmarshal(bodyBytes, &tags); err != nil {
		return nil, fmt.Errorf("decoding JSON: %w", err)
	}

	var versions []base.Internal
	for _, tag := range tags.Tags {
		versions = append(versions, base.Internal{Ref: tag})
	}

	return base.SortVersions(versions), nil
}

// In fetches the bundled Yarn Berry CLI binary for a specific version and
// computes its SHA256 checksum.
func (w *YarnBerryWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("https://repo.yarnpkg.com/%s/packages/yarnpkg-cli/bin/yarn.js", ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching yarn berry binary: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return base.Release{}, fmt.Errorf("computing SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256sum,
	}, nil
}
