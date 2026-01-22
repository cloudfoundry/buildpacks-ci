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

type mockRClient struct {
	responses map[string]mockResponse
}

type mockResponse struct {
	body   string
	status int
}

func (m *mockRClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}

	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockRClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("RWatcher", func() {
	var (
		client  *mockRClient
		watcher *watchers.RWatcher
	)

	BeforeEach(func() {
		client = &mockRClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewRWatcher(client)
	})

	Describe("Check", func() {
		Context("when the CRAN website returns valid HTML", func() {
			It("returns sorted versions from the R-4 directory", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/rlang.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://cran.r-project.org/src/base/R-4/"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(7))
				Expect(versions[0].Ref).To(Equal("4.0.0"))
				Expect(versions[1].Ref).To(Equal("4.0.1"))
				Expect(versions[2].Ref).To(Equal("4.0.2"))
				Expect(versions[3].Ref).To(Equal("4.0.3"))
				Expect(versions[4].Ref).To(Equal("4.0.4"))
				Expect(versions[5].Ref).To(Equal("4.0.5"))
				Expect(versions[6].Ref).To(Equal("4.1.0"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				html := `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html><body>
<table>
<tr><td><a href="R-4.0.0.tar.gz">R-4.0.0.tar.gz</a></td></tr>
<tr><td><a href="R-4.0.1.tar.gz">R-4.0.1.tar.gz</a></td></tr>
<tr><td><a href="R-4.0.2.tar.gz">R-4.0.2.tar.gz</a></td></tr>
<tr><td><a href="R-4.0.3.tar.gz">R-4.0.3.tar.gz</a></td></tr>
<tr><td><a href="R-4.0.4.tar.gz">R-4.0.4.tar.gz</a></td></tr>
<tr><td><a href="R-4.0.5.tar.gz">R-4.0.5.tar.gz</a></td></tr>
<tr><td><a href="R-4.1.0.tar.gz">R-4.1.0.tar.gz</a></td></tr>
<tr><td><a href="R-4.1.1.tar.gz">R-4.1.1.tar.gz</a></td></tr>
<tr><td><a href="R-4.1.2.tar.gz">R-4.1.2.tar.gz</a></td></tr>
<tr><td><a href="R-4.1.3.tar.gz">R-4.1.3.tar.gz</a></td></tr>
<tr><td><a href="R-4.2.0.tar.gz">R-4.2.0.tar.gz</a></td></tr>
<tr><td><a href="R-4.2.1.tar.gz">R-4.2.1.tar.gz</a></td></tr>
<tr><td><a href="R-4.2.2.tar.gz">R-4.2.2.tar.gz</a></td></tr>
</table>
</body></html>`

				client.responses["https://cran.r-project.org/src/base/R-4/"] = mockResponse{
					body:   html,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("4.0.3"))
				Expect(versions[9].Ref).To(Equal("4.2.2"))
			})
		})

		Context("when the HTML cannot be parsed", func() {
			It("returns an error", func() {
				client.responses["https://cran.r-project.org/src/base/R-4/"] = mockResponse{
					body:   "invalid html",
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not parse R releases"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch R releases"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific R version", func() {
			It("returns the release details with computed SHA256", func() {
				client.responses["https://cran.r-project.org/src/base/R-3/R-3.3.2.tar.gz"] = mockResponse{
					body:   "hello",
					status: 200,
				}

				release, err := watcher.In("3.3.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.3.2"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/base/R-3/R-3.3.2.tar.gz"))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when fetching R version 4.0.3", func() {
			It("constructs the correct URL with R-4 base directory", func() {
				client.responses["https://cran.r-project.org/src/base/R-4/R-4.0.3.tar.gz"] = mockResponse{
					body:   "test content",
					status: 200,
				}

				release, err := watcher.In("4.0.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("4.0.3"))
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/base/R-4/R-4.0.3.tar.gz"))
				Expect(release.SHA256).To(HaveLen(64))
			})
		})

		Context("when fetching R version 3.6.1", func() {
			It("constructs the correct URL with R-3 base directory", func() {
				client.responses["https://cran.r-project.org/src/base/R-3/R-3.6.1.tar.gz"] = mockResponse{
					body:   "another test",
					status: 200,
				}

				release, err := watcher.In("3.6.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://cran.r-project.org/src/base/R-3/R-3.6.1.tar.gz"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.In("4.0.3")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download R release"))
			})
		})

		Context("when the version format is invalid", func() {
			It("returns an error", func() {
				_, err := watcher.In("")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("invalid version format"))
			})
		})
	})
})
