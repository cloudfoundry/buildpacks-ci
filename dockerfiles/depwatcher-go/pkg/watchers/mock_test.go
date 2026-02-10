package watchers_test

import (
	"io"
	"net/http"
	"strings"
)

// MockHTTPClient is a shared mock HTTP client for testing watchers.
// It supports both simple single-response mocks and URL-mapped responses.
type MockHTTPClient struct {
	// Response is used for simple single-response mocks
	Response string

	// Responses maps URLs to response strings for multi-URL mocks
	Responses map[string]string

	// StatusCode is the HTTP status code to return (defaults to 200)
	StatusCode int

	// Err is the error to return (if set, overrides response)
	Err error
}

// Get implements the HTTPClient interface
func (m *MockHTTPClient) Get(url string) (*http.Response, error) {
	if m.Err != nil {
		return nil, m.Err
	}

	statusCode := m.StatusCode
	if statusCode == 0 {
		statusCode = http.StatusOK
	}

	// Check URL-mapped responses first
	if m.Responses != nil {
		if response, ok := m.Responses[url]; ok {
			return &http.Response{
				StatusCode: statusCode,
				Body:       io.NopCloser(strings.NewReader(response)),
			}, nil
		}
		// Check for default response
		if response, ok := m.Responses["default"]; ok {
			return &http.Response{
				StatusCode: statusCode,
				Body:       io.NopCloser(strings.NewReader(response)),
			}, nil
		}
	}

	// Fall back to single Response field
	return &http.Response{
		StatusCode: statusCode,
		Body:       io.NopCloser(strings.NewReader(m.Response)),
	}, nil
}

// GetWithHeaders implements the HTTPClient interface
func (m *MockHTTPClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}
