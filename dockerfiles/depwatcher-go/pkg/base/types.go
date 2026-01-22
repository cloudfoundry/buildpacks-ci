package base

import "net/http"

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
