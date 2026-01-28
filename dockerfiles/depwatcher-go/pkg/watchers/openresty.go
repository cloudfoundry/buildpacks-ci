package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type OpenrestyWatcher struct {
	client base.HTTPClient
}

func NewOpenrestyWatcher(client base.HTTPClient) *OpenrestyWatcher {
	return &OpenrestyWatcher{client: client}
}

// Check returns OpenResty versions from GitHub tags matching 4-part version pattern.
func (w *OpenrestyWatcher) Check() ([]base.Internal, error) {
	githubWatcher := NewGithubTagsWatcher(w.client, "openresty/openresty")
	allVersions, err := githubWatcher.Check(`\d+\.\d+\.\d+\.\d+$`)
	if err != nil {
		return nil, err
	}

	versionPattern := regexp.MustCompile(`^v?(\d+\.\d+\.\d+\.\d+)$`)
	var versions []base.Internal

	for _, v := range allVersions {
		matches := versionPattern.FindStringSubmatch(v.Ref)
		if len(matches) == 2 {
			versions = append(versions, base.Internal{Ref: matches[1]})
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

	return versions, nil
}

// In returns download URL, PGP signature, and SHA256 for a specific OpenResty version.
func (w *OpenrestyWatcher) In(version string) (base.Release, error) {
	url := fmt.Sprintf("http://openresty.org/download/openresty-%s.tar.gz", version)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to fetch openresty tarball: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	_, err = io.Copy(hash, resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    version,
		URL:    url,
		PGP:    fmt.Sprintf("http://openresty.org/download/openresty-%s.tar.gz.asc", version),
		SHA256: sha256sum,
	}, nil
}
