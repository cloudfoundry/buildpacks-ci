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
	Ref            string `json:"ref"`
	URL            string `json:"url"`
	SHA512         string `json:"sha512,omitempty"`
	SHA256         string `json:"sha256,omitempty"`
	SHA1           string `json:"sha1,omitempty"`
	MD5            string `json:"md5_digest,omitempty"`
	PGP            string `json:"pgp,omitempty"`
	GitCommitSHA   string `json:"git_commit_sha,omitempty"`
	RuntimeVersion string `json:"runtime_version,omitempty"`
}

// HTTPClient abstracts HTTP operations for testing
type HTTPClient interface {
	Get(url string) (*http.Response, error)
	GetWithHeaders(url string, headers http.Header) (*http.Response, error)
	// GetRaw performs a GET request and returns the response regardless of status code.
	// Unlike GetWithHeaders, it does NOT return an error for non-2xx responses.
	// Use this when you need to inspect the status code yourself (e.g. for fallback logic).
	GetRaw(url string, headers http.Header) (*http.Response, error)
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
