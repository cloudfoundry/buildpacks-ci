package base

import (
	"net/http"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

// Internal represents a version reference returned by Check
type Internal struct {
	Ref string `json:"ref"`
}

// Release represents full version details returned by In
type Release struct {
	Ref    string `json:"ref"`
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
	MD5    string `json:"md5_digest,omitempty"`
	PGP    string `json:"pgp,omitempty"`
}

// HTTPClient abstracts HTTP operations for testing
type HTTPClient interface {
	Get(url string) (*http.Response, error)
	GetWithHeaders(url string, headers http.Header) (*http.Response, error)
}

// SortVersions sorts a slice of Internal versions using semver comparison
// Falls back to string comparison if semver parsing fails
func SortVersions(internals []Internal) []Internal {
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
