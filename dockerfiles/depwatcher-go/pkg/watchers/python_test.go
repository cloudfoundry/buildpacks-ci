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

type mockPythonClient struct {
	responses map[string]string
}

func (m *mockPythonClient) Get(url string) (*http.Response, error) {
	body, ok := m.responses[url]
	if !ok {
		return &http.Response{
			StatusCode: 404,
			Body:       io.NopCloser(strings.NewReader("not found")),
		}, fmt.Errorf("URL not mocked: %s", url)
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func (m *mockPythonClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockPythonClient() *mockPythonClient {
	return &mockPythonClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("PythonWatcher", func() {
	var (
		watcher    *watchers.PythonWatcher
		mockClient *mockPythonClient
	)

	BeforeEach(func() {
		mockClient = newMockPythonClient()
	})

	Describe("Check", func() {
		Context("when the Python downloads page is scraped successfully", func() {
			BeforeEach(func() {
				html := `
<!DOCTYPE html>
<html>
<body>
	<div class="release-number"><a href="/downloads/release/python-31220/">Python 3.12.20</a></div>
	<div class="release-number"><a href="/downloads/release/python-3117/">Python 3.11.7</a></div>
	<div class="release-number"><a href="/downloads/release/python-31015/">Python 3.10.15</a></div>
	<div class="release-number"><a href="/downloads/release/python-397/">Python 3.9.7</a></div>
</body>
</html>`
				mockClient.responses["https://www.python.org/downloads/"] = html
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns Python versions in reverse order (oldest first)", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("3.9.7"))
				Expect(versions[1].Ref).To(Equal("3.10.15"))
				Expect(versions[2].Ref).To(Equal("3.11.7"))
				Expect(versions[3].Ref).To(Equal("3.12.20"))
			})

			It("strips 'Python' prefix from version strings", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				for _, v := range versions {
					Expect(v.Ref).NotTo(ContainSubstring("Python"))
				}
			})
		})

		Context("when there are more than 50 versions", func() {
			BeforeEach(func() {
				var html strings.Builder
				html.WriteString("<html><body>")
				for i := 0; i < 60; i++ {
					html.WriteString(fmt.Sprintf(`<div class="release-number"><a href="/downloads/release/python-3%d0/">Python 3.%d.0</a></div>`, i, i))
				}
				html.WriteString("</body></html>")

				mockClient.responses["https://www.python.org/downloads/"] = html.String()
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("limits results to the first 50 versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(50))
			})
		})

		Context("when the page cannot be fetched", func() {
			BeforeEach(func() {
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching python downloads page"))
			})
		})

		Context("when the page has no version elements", func() {
			BeforeEach(func() {
				html := `<html><body><p>No releases here</p></body></html>`
				mockClient.responses["https://www.python.org/downloads/"] = html
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not parse python website"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching Python 3.11.7 (7 column layout)", func() {
			BeforeEach(func() {
				releaseHTML := `
<!DOCTYPE html>
<html>
<body>
	<table>
		<tr>
			<td>Version</td>
			<td>OS</td>
			<td>Description</td>
			<td>File type</td>
			<td><a href="https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz">Gzipped source tarball</a></td>
			<td>Size</td>
			<td>7a704b20e1b3a3a1c9bc8e05e433e7a3</td>
		</tr>
	</table>
</body>
</html>`
				mockClient.responses["https://www.python.org/downloads/release/python-3117/"] = releaseHTML
				mockClient.responses["https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz"] = "fake-tarball-content"
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns the release details with correct URL", func() {
				release, err := watcher.In("3.11.7")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.11.7"))
				Expect(release.URL).To(Equal("https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz"))
			})

			It("extracts MD5 from the 7th column", func() {
				release, err := watcher.In("3.11.7")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).NotTo(BeEmpty())
			})

			It("calculates SHA256", func() {
				release, err := watcher.In("3.11.7")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when fetching Python 3.12.20 (8 column layout with Sigstore)", func() {
			BeforeEach(func() {
				releaseHTML := `
<!DOCTYPE html>
<html>
<body>
	<table>
		<tr>
			<td>Version</td>
			<td>OS</td>
			<td>Description</td>
			<td>File type</td>
			<td><a href="https://www.python.org/ftp/python/3.12.20/Python-3.12.20.tgz">Gzipped source tarball</a></td>
			<td>Size</td>
			<td>Sigstore</td>
			<td>9b825c1e4c3b4f5d8a9c7e1f2d3a4b5c</td>
		</tr>
	</table>
</body>
</html>`
				mockClient.responses["https://www.python.org/downloads/release/python-31220/"] = releaseHTML
				mockClient.responses["https://www.python.org/ftp/python/3.12.20/Python-3.12.20.tgz"] = "fake-tarball-content"
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns the release details", func() {
				release, err := watcher.In("3.12.20")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.12.20"))
				Expect(release.URL).To(Equal("https://www.python.org/ftp/python/3.12.20/Python-3.12.20.tgz"))
			})

			It("extracts MD5 from the 8th column", func() {
				release, err := watcher.In("3.12.20")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).NotTo(BeEmpty())
			})
		})

		Context("when the release page is not found", func() {
			BeforeEach(func() {
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("99.99.99")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching python release page"))
			})
		})

		Context("when the tarball link is not found", func() {
			BeforeEach(func() {
				releaseHTML := `<html><body><p>No downloads here</p></body></html>`
				mockClient.responses["https://www.python.org/downloads/release/python-3117/"] = releaseHTML
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("3.11.7")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find download URL"))
			})
		})

		Context("when version has non-digit characters", func() {
			BeforeEach(func() {
				releaseHTML := `
<!DOCTYPE html>
<html>
<body>
	<table>
		<tr>
			<td>Version</td>
			<td>OS</td>
			<td>Description</td>
			<td>File type</td>
			<td><a href="https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz">Gzipped source tarball</a></td>
			<td>Size</td>
			<td>abc123def456</td>
		</tr>
	</table>
</body>
</html>`
				mockClient.responses["https://www.python.org/downloads/release/python-3117/"] = releaseHTML
				mockClient.responses["https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz"] = "fake"
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("strips non-digits to create the URL slug", func() {
				release, err := watcher.In("3.11.7")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz"))
			})
		})
	})
})
