//go:build !integration
// +build !integration

package factory_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/internal/factory"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

// mockHTTPClient is a mock HTTP client for unit testing.
// It allows tests to run without making real HTTP requests.
type mockHTTPClient struct {
	responses map[string]string
}

func (m *mockHTTPClient) Get(url string) (*http.Response, error) {
	body, ok := m.responses[url]
	if !ok {
		return nil, fmt.Errorf("URL not mocked: %s", url)
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func (m *mockHTTPClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockHTTPClient() *mockHTTPClient {
	return &mockHTTPClient{
		responses: make(map[string]string),
	}
}

func TestFactory(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Factory Unit Test Suite")
}

var _ = Describe("Factory Unit Tests", func() {
	Describe("CheckWithClient", func() {
		Context("error handling", func() {
			It("returns error for unknown source type", func() {
				mockClient := newMockHTTPClient()
				source := factory.Source{
					Type: "unknown_type",
				}

				_, err := factory.CheckWithClient(source, nil, mockClient)
				Expect(err).To(MatchError("unknown type: unknown_type"))
			})

			It("handles HTTP client errors gracefully", func() {
				mockClient := newMockHTTPClient()
				// Don't add any responses, so all URLs will fail
				source := factory.Source{
					Type: "php",
				}

				_, err := factory.CheckWithClient(source, nil, mockClient)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("URL not mocked"))
			})
		})

		Context("client parameter handling", func() {
			It("uses provided mock client", func() {
				mockClient := newMockHTTPClient()
				source := factory.Source{
					Type: "unknown_type",
				}

				// Should use the mock client and return our error
				_, err := factory.CheckWithClient(source, nil, mockClient)
				Expect(err).To(HaveOccurred())
			})
		})
	})

	Describe("InWithClient", func() {
		Context("error handling", func() {
			It("returns error for unknown source type", func() {
				mockClient := newMockHTTPClient()
				source := factory.Source{
					Type: "unknown_type",
				}
				version := base.Internal{Ref: "1.0.0"}

				_, err := factory.InWithClient(source, version, mockClient)
				Expect(err).To(MatchError("unknown type: unknown_type"))
			})

			It("handles HTTP client errors gracefully", func() {
				mockClient := newMockHTTPClient()
				// Don't add any responses, so all URLs will fail
				source := factory.Source{
					Type: "php",
				}
				version := base.Internal{Ref: "8.2.0"}

				_, err := factory.InWithClient(source, version, mockClient)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("URL not mocked"))
			})
		})

		Context("client parameter handling", func() {
			It("uses provided mock client", func() {
				mockClient := newMockHTTPClient()
				source := factory.Source{
					Type: "unknown_type",
				}
				version := base.Internal{Ref: "1.0.0"}

				// Should use the mock client and return our error
				_, err := factory.InWithClient(source, version, mockClient)
				Expect(err).To(HaveOccurred())
			})
		})
	})

	Describe("SetupGithubToken", func() {
		AfterEach(func() {
			os.Unsetenv("GITHUB_TOKEN")
		})

		It("sets GITHUB_TOKEN environment variable from source.GithubToken", func() {
			source := factory.Source{
				Type:        "github_releases",
				Repo:        "cloudfoundry/hwc",
				GithubToken: "test_token_12345",
			}

			factory.SetupGithubToken(&source)

			Expect(os.Getenv("GITHUB_TOKEN")).To(Equal("test_token_12345"))
		})

		It("clears source.GithubToken after setting env var", func() {
			source := factory.Source{
				Type:        "github_releases",
				Repo:        "cloudfoundry/hwc",
				GithubToken: "test_token_12345",
			}

			factory.SetupGithubToken(&source)

			Expect(source.GithubToken).To(Equal(""))
		})

		It("does nothing when GithubToken is empty", func() {
			source := factory.Source{
				Type: "github_releases",
				Repo: "cloudfoundry/hwc",
			}

			factory.SetupGithubToken(&source)

			Expect(os.Getenv("GITHUB_TOKEN")).To(Equal(""))
		})
	})

	Describe("ParseCheckRequest", func() {
		It("parses valid JSON into CheckRequest", func() {
			jsonData := `{
				"source": {
					"type": "ruby",
					"version_filter": "3.2.X"
				},
				"version": {
					"ref": "3.2.0"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Source.VersionFilter).To(Equal("3.2.X"))
			Expect(req.Version).NotTo(BeNil())
			Expect(req.Version.Ref).To(Equal("3.2.0"))
		})

		It("handles missing version field", func() {
			jsonData := `{
				"source": {
					"type": "ruby"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Version).To(BeNil())
		})

		It("returns error for invalid JSON", func() {
			jsonData := `{invalid json}`

			_, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("parsing check request"))
		})

		It("parses github_releases with all options", func() {
			jsonData := `{
				"source": {
					"type": "github_releases",
					"repo": "cloudfoundry/hwc",
					"extension": ".exe",
					"prerelease": true,
					"fetch_source": true,
					"version_filter": "1.0.X",
					"github_token": "ghp_token"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_releases"))
			Expect(req.Source.Repo).To(Equal("cloudfoundry/hwc"))
			Expect(req.Source.Extension).To(Equal(".exe"))
			Expect(req.Source.Prerelease).To(BeTrue())
			Expect(req.Source.FetchSource).To(BeTrue())
			Expect(req.Source.VersionFilter).To(Equal("1.0.X"))
			Expect(req.Source.GithubToken).To(Equal("ghp_token"))
		})

		It("parses github_tags with tag_regex", func() {
			jsonData := `{
				"source": {
					"type": "github_tags",
					"repo": "ruby/ruby",
					"tag_regex": "^v[\\d_]+$"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_tags"))
			Expect(req.Source.Repo).To(Equal("ruby/ruby"))
			Expect(req.Source.TagRegex).To(Equal(`^v[\d_]+$`))
		})

		It("parses npm with name field", func() {
			jsonData := `{
				"source": {
					"type": "npm",
					"name": "typescript"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("npm"))
			Expect(req.Source.Name).To(Equal("typescript"))
		})
	})

	Describe("ParseInRequest", func() {
		It("parses valid JSON into InRequest", func() {
			jsonData := `{
				"source": {
					"type": "ruby",
					"version_filter": "3.2.X"
				},
				"version": {
					"ref": "3.2.0"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Source.VersionFilter).To(Equal("3.2.X"))
			Expect(req.Version.Ref).To(Equal("3.2.0"))
		})

		It("returns error for invalid JSON", func() {
			jsonData := `{invalid json}`

			_, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("parsing in request"))
		})

		It("parses github_releases with all options", func() {
			jsonData := `{
				"source": {
					"type": "github_releases",
					"repo": "cloudfoundry/hwc",
					"extension": ".exe",
					"fetch_source": true
				},
				"version": {
					"ref": "1.0.0"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_releases"))
			Expect(req.Source.Repo).To(Equal("cloudfoundry/hwc"))
			Expect(req.Source.Extension).To(Equal(".exe"))
			Expect(req.Source.FetchSource).To(BeTrue())
			Expect(req.Version.Ref).To(Equal("1.0.0"))
		})

		It("requires version field", func() {
			jsonData := `{
				"source": {
					"type": "ruby"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			// JSON parsing succeeds, but version.ref will be empty
			Expect(err).NotTo(HaveOccurred())
			Expect(req.Version.Ref).To(Equal(""))
		})
	})

	Describe("CheckResponse marshaling", func() {
		It("marshals to JSON array", func() {
			response := factory.CheckResponse{
				base.Internal{Ref: "3.2.0"},
				base.Internal{Ref: "3.2.1"},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`[
				{"ref": "3.2.0"},
				{"ref": "3.2.1"}
			]`))
		})

		It("marshals empty response", func() {
			response := factory.CheckResponse{}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`[]`))
		})
	})

	Describe("InResponse marshaling", func() {
		It("marshals version and metadata", func() {
			response := factory.InResponse{
				Version: base.Internal{Ref: "3.2.0"},
				Metadata: []factory.MetadataField{
					{Name: "url", Value: "https://example.com"},
					{Name: "sha256", Value: "abc123"},
				},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`{
				"version": {"ref": "3.2.0"},
				"metadata": [
					{"name": "url", "value": "https://example.com"},
					{"name": "sha256", "value": "abc123"}
				]
			}`))
		})

		It("handles nil metadata", func() {
			response := factory.InResponse{
				Version: base.Internal{Ref: "3.2.0"},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`{
				"version": {"ref": "3.2.0"}
			}`))
		})
	})
})
