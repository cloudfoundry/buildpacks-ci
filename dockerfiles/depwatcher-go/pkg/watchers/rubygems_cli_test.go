package watchers_test

import (
	"fmt"
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockRubygemsCLIClient struct {
	responses map[string]mockResponse
}

func (m *mockRubygemsCLIClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}

	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockRubygemsCLIClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("RubygemsCLIWatcher", func() {
	var (
		watcher *watchers.RubygemsCLIWatcher
		client  *mockRubygemsCLIClient
	)

	BeforeEach(func() {
		client = &mockRubygemsCLIClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewRubygemsCLIWatcher(client)
	})

	Context("Check", func() {
		It("returns sorted versions from RubyGems API", func() {
			apiJSON := `[
				{"number": "3.4.0"},
				{"number": "3.4.1"},
				{"number": "3.5.0"}
			]`

			client.responses["https://rubygems.org/api/v1/versions/rubygems-update.json"] = mockResponse{
				body:   apiJSON,
				status: 200,
			}

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("3.4.0"))
			Expect(versions[1].Ref).To(Equal("3.4.1"))
			Expect(versions[2].Ref).To(Equal("3.5.0"))
		})

		It("sorts versions by semver", func() {
			apiJSON := `[
				{"number": "3.10.0"},
				{"number": "3.2.0"},
				{"number": "3.9.0"}
			]`

			client.responses["https://rubygems.org/api/v1/versions/rubygems-update.json"] = mockResponse{
				body:   apiJSON,
				status: 200,
			}

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("3.2.0"))
			Expect(versions[1].Ref).To(Equal("3.9.0"))
			Expect(versions[2].Ref).To(Equal("3.10.0"))
		})

		It("handles pre-release versions", func() {
			apiJSON := `[
				{"number": "3.4.0.rc1"},
				{"number": "3.4.0"},
				{"number": "3.4.1.beta"}
			]`

			client.responses["https://rubygems.org/api/v1/versions/rubygems-update.json"] = mockResponse{
				body:   apiJSON,
				status: 200,
			}

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
		})

		Context("when the API request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching rubygems API"))
			})
		})

		Context("when the API returns no versions", func() {
			It("returns an error", func() {
				client.responses["https://rubygems.org/api/v1/versions/rubygems-update.json"] = mockResponse{
					body:   "[]",
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions found"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				apiJSON := `[
					{"number": "3.0.0"},
					{"number": "3.1.0"},
					{"number": "3.2.0"},
					{"number": "3.3.0"},
					{"number": "3.4.0"},
					{"number": "3.5.0"},
					{"number": "3.6.0"},
					{"number": "3.7.0"},
					{"number": "3.8.0"},
					{"number": "3.9.0"},
					{"number": "4.0.0"},
					{"number": "4.1.0"}
				]`

				client.responses["https://rubygems.org/api/v1/versions/rubygems-update.json"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				versions, err := watcher.Check()

				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("3.2.0"))
				Expect(versions[9].Ref).To(Equal("4.1.0"))
			})
		})
	})

	Context("In", func() {
		It("returns download URL for version", func() {
			release, err := watcher.In("3.4.10")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.4.10"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.4.10.tgz"))
		})

		It("constructs URL with version", func() {
			release, err := watcher.In("3.5.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.5.0"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.5.0.tgz"))
		})

		It("handles pre-release versions", func() {
			release, err := watcher.In("3.4.0.rc1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.4.0.rc1"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.4.0.rc1.tgz"))
		})
	})
})
