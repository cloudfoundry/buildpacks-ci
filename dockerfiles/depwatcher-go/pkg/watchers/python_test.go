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
		Context("when the Python API returns releases successfully", func() {
			BeforeEach(func() {
				apiJSON := `[
					{"name": "Python 3.12.20", "is_published": true, "pre_release": false},
					{"name": "Python 3.11.7", "is_published": true, "pre_release": false},
					{"name": "Python 3.10.15", "is_published": true, "pre_release": false},
					{"name": "Python 3.9.7", "is_published": true, "pre_release": false}
				]`
				mockClient.responses["https://www.python.org/api/v2/downloads/release/?is_published=true"] = apiJSON
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns Python versions from the API", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("3.12.20"))
				Expect(versions[1].Ref).To(Equal("3.11.7"))
				Expect(versions[2].Ref).To(Equal("3.10.15"))
				Expect(versions[3].Ref).To(Equal("3.9.7"))
			})

			It("extracts version numbers from release names", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				for _, v := range versions {
					Expect(v.Ref).NotTo(ContainSubstring("Python"))
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+$`))
				}
			})
		})

		Context("when the API returns pre-releases", func() {
			BeforeEach(func() {
				apiJSON := `[
					{"name": "Python 3.13.0", "is_published": true, "pre_release": false},
					{"name": "Python 3.13.0rc2", "is_published": true, "pre_release": true},
					{"name": "Python 3.13.0rc1", "is_published": true, "pre_release": true},
					{"name": "Python 3.12.5", "is_published": true, "pre_release": false}
				]`
				mockClient.responses["https://www.python.org/api/v2/downloads/release/?is_published=true"] = apiJSON
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("filters out pre-releases", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("3.13.0"))
				Expect(versions[1].Ref).To(Equal("3.12.5"))
			})
		})

		Context("when there are more than 50 versions (API)", func() {
			BeforeEach(func() {
				var releases strings.Builder
				releases.WriteString("[")
				for i := 0; i < 60; i++ {
					if i > 0 {
						releases.WriteString(",")
					}
					releases.WriteString(fmt.Sprintf(`{"name":"Python 3.%d.0","is_published":true,"pre_release":false}`, i))
				}
				releases.WriteString("]")

				mockClient.responses["https://www.python.org/api/v2/downloads/release/?is_published=true"] = releases.String()
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("limits results to the first 50 versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(50))
			})
		})

		Context("when the API request fails", func() {
			BeforeEach(func() {
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching python API"))
			})
		})

		Context("when the API returns no versions", func() {
			BeforeEach(func() {
				mockClient.responses["https://www.python.org/api/v2/downloads/release/?is_published=true"] = "[]"
				watcher = watchers.NewPythonWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions found"))
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
