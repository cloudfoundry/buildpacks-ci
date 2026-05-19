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

type mockJRebelClient struct {
	responses map[string]mockResponse
}

func (m *mockJRebelClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockJRebelClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockJRebelClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

const jrebelReleasesPage = "https://www.jrebel.com/jrebel-releases"
const jrebelDlBase = "https://dl.zeroturnaround.com/jrebel/releases/jrebel-%s-nosetup.zip"

func jrebelHTML(versions ...string) string {
	var links strings.Builder
	for _, v := range versions {
		links.WriteString(fmt.Sprintf(`<a href="https://dl.zeroturnaround.com/jrebel/releases/jrebel-%s-nosetup.zip">Download</a>`, v))
	}
	return "<html><body>" + links.String() + "</body></html>"
}

var _ = Describe("JRebelWatcher", func() {
	var (
		client  *mockJRebelClient
		watcher *watchers.JRebelWatcher
	)

	BeforeEach(func() {
		client = &mockJRebelClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewJRebelWatcher(client)
	})

	Describe("Check", func() {
		Context("when the releases page lists versions", func() {
			It("returns sorted versions", func() {
				client.responses[jrebelReleasesPage] = mockResponse{
					body:   jrebelHTML("2025.4.1", "2025.4.2", "2025.3.0"),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("2025.3.0"))
				Expect(versions[1].Ref).To(Equal("2025.4.1"))
				Expect(versions[2].Ref).To(Equal("2025.4.2"))
			})

			It("deduplicates versions appearing multiple times", func() {
				client.responses[jrebelReleasesPage] = mockResponse{
					body:   jrebelHTML("2025.4.1", "2025.4.1", "2025.4.2"),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
			})

			It("ignores links that do not match the versioned nosetup pattern", func() {
				html := `<html><body>
<a href="https://dl.zeroturnaround.com/jrebel/releases/jrebel-stable-nosetup.zip">stable</a>
<a href="https://dl.zeroturnaround.com/jrebel/releases/jrebel-2026.2.1-nosetup.zip">Download</a>
</body></html>`
				client.responses[jrebelReleasesPage] = mockResponse{body: html, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("2026.2.1"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the 10 most recent", func() {
				var vers []string
				for i := 1; i <= 12; i++ {
					vers = append(vers, fmt.Sprintf("2025.%d.0", i))
				}
				client.responses[jrebelReleasesPage] = mockResponse{
					body:   jrebelHTML(vers...),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("2025.3.0"))
				Expect(versions[9].Ref).To(Equal("2025.12.0"))
			})
		})

		Context("when no versions are found", func() {
			It("returns an error", func() {
				client.responses[jrebelReleasesPage] = mockResponse{body: "<html><body></body></html>", status: 200}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no JRebel versions found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch JRebel releases page"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("returns the release with URL and computed SHA256", func() {
				url := fmt.Sprintf(jrebelDlBase, "2026.2.1")
				client.responses[url] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("2026.2.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("2026.2.1"))
				Expect(release.URL).To(Equal(url))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("2026.2.1")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download JRebel"))
			})
		})
	})
})
