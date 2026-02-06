package base

import (
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
)

// HTTPClientImpl implements HTTPClient with OAuth token injection and redirect handling
type HTTPClientImpl struct {
	client *http.Client
}

// NewHTTPClient creates a new HTTP client
// If insecure is true, TLS certificate verification is disabled
func NewHTTPClient(insecure bool) *HTTPClientImpl {
	client := &http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			// Follow up to 10 redirects (default)
			if len(via) >= 10 {
				return fmt.Errorf("stopped after 10 redirects")
			}
			return nil
		},
	}

	if insecure {
		client.Transport = &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
	}

	return &HTTPClientImpl{client: client}
}

// Get performs an HTTP GET request
func (c *HTTPClientImpl) Get(url string) (*http.Response, error) {
	return c.GetWithHeaders(url, nil)
}

// GetWithHeaders performs an HTTP GET request with custom headers
func (c *HTTPClientImpl) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	// Inject GitHub token from environment if present
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		req.Header.Set("Authorization", fmt.Sprintf("token %s", token))
	}

	// Add custom headers
	if headers != nil {
		for key, values := range headers {
			for _, value := range values {
				req.Header.Add(key, value)
			}
		}
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}

	// Check for successful response
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		resp.Body.Close()
		return nil, fmt.Errorf("request failed with status %d: %s", resp.StatusCode, url)
	}

	return resp, nil
}

// GetSHA256 downloads a file and returns its SHA256 hash
func GetSHA256(client HTTPClient, url string) (string, error) {
	resp, err := client.Get(url)
	if err != nil {
		return "", fmt.Errorf("downloading file: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return "", fmt.Errorf("hashing file: %w", err)
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}
