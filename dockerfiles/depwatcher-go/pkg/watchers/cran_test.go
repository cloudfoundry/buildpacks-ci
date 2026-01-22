package watchers_test

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockCRANClient struct {
	responses map[string]mockResponse
}

func (m *mockCRANClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}

	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockCRANClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("CRANWatcher", func() {
	var client *mockCRANClient

	BeforeEach(func() {
		client = &mockCRANClient{responses: make(map[string]mockResponse)}
	})

	Describe("Check", func() {
		Context("when checking Rserve package", func() {
			It("returns the latest version in semver form", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/rserve.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://cran.r-project.org/web/packages/Rserve/index.html"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				watcher := watchers.NewCRANWatcher(client, "Rserve")
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("1.7.3"))
			})
		})

		Context("when checking forecast package", func() {
			It("returns the latest version", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/forecast.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://cran.r-project.org/web/packages/forecast/index.html"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				watcher := watchers.NewCRANWatcher(client, "forecast")
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("8.4"))
			})
		})

		Context("when checking shiny package", func() {
			It("returns the latest version", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/shiny.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://cran.r-project.org/web/packages/shiny/index.html"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				watcher := watchers.NewCRANWatcher(client, "shiny")
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("1.2.0"))
			})
		})

		Context("when checking plumber package", func() {
			It("returns the latest version", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/plumber.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://cran.r-project.org/web/packages/plumber/index.html"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				watcher := watchers.NewCRANWatcher(client, "plumber")
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("0.4.6"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				watcher := watchers.NewCRANWatcher(client, "Rserve")
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch CRAN package page"))
			})
		})

		Context("when the HTML cannot be parsed", func() {
			It("returns an error", func() {
				client.responses["https://cran.r-project.org/web/packages/test/index.html"] = mockResponse{
					body:   "<html><body><p>No version info</p></body></html>",
					status: 200,
				}

				watcher := watchers.NewCRANWatcher(client, "test")
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not parse test website"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching Rserve version", func() {
			It("constructs URL with hyphens for patch version", func() {
				watcher := watchers.NewCRANWatcher(client, "Rserve")
				release, err := watcher.In("1.7.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.7.3"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/contrib/Rserve_1.7-3.tar.gz"))
			})
		})

		Context("when fetching forecast version", func() {
			It("constructs URL with dots for patch version", func() {
				watcher := watchers.NewCRANWatcher(client, "forecast")
				release, err := watcher.In("8.4")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.4"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/contrib/forecast_8.4.tar.gz"))
			})
		})

		Context("when fetching shiny version", func() {
			It("constructs URL correctly", func() {
				watcher := watchers.NewCRANWatcher(client, "shiny")
				release, err := watcher.In("1.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.0"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/contrib/shiny_1.2.0.tar.gz"))
			})
		})

		Context("when fetching plumber version", func() {
			It("constructs URL correctly", func() {
				watcher := watchers.NewCRANWatcher(client, "plumber")
				release, err := watcher.In("0.4.6")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("0.4.6"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/contrib/plumber_0.4.6.tar.gz"))
			})
		})

		Context("when the version format is invalid", func() {
			It("returns an error", func() {
				watcher := watchers.NewCRANWatcher(client, "test")
				_, err := watcher.In("1")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("invalid version format"))
			})
		})
	})
})
