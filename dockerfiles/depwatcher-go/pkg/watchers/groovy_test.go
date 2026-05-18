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

type mockGroovyClient struct {
	responses map[string]mockResponse
}

func (m *mockGroovyClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockGroovyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockGroovyClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

const groovyDirURL = "https://groovy.jfrog.io/artifactory/api/storage/dist-release-local/groovy-zips/"
const groovyMetaBase = "https://groovy.jfrog.io/artifactory/api/storage/dist-release-local/groovy-zips"
const groovyDlBase = "https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips"

var _ = Describe("GroovyWatcher", func() {
	var (
		client  *mockGroovyClient
		watcher *watchers.GroovyWatcher
	)

	BeforeEach(func() {
		client = &mockGroovyClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewGroovyWatcher(client)
	})

	Describe("Check", func() {
		Context("when the Artifactory listing returns files", func() {
			It("returns sorted stable versions, excluding pre-releases and .asc files", func() {
				dirJSON := `{"children": [
					{"uri": "/apache-groovy-binary-4.0.29.zip", "folder": false},
					{"uri": "/apache-groovy-binary-4.0.29.zip.asc", "folder": false},
					{"uri": "/apache-groovy-binary-4.0.30.zip", "folder": false},
					{"uri": "/apache-groovy-binary-4.0.0-alpha-1.zip", "folder": false},
					{"uri": "/apache-groovy-binary-4.0.0-beta-1.zip", "folder": false},
					{"uri": "/apache-groovy-binary-4.0.0-rc-1.zip", "folder": false}
				]}`

				client.responses[groovyDirURL] = mockResponse{body: dirJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("4.0.29"))
				Expect(versions[1].Ref).To(Equal("4.0.30"))
			})

			It("skips folder entries", func() {
				dirJSON := `{"children": [
					{"uri": "/some-folder", "folder": true},
					{"uri": "/apache-groovy-binary-4.0.32.zip", "folder": false}
				]}`

				client.responses[groovyDirURL] = mockResponse{body: dirJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("4.0.32"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the 10 most recent", func() {
				var children []string
				for i := 1; i <= 12; i++ {
					children = append(children, fmt.Sprintf(`{"uri": "/apache-groovy-binary-4.0.%d.zip", "folder": false}`, i))
				}
				dirJSON := fmt.Sprintf(`{"children": [%s]}`, strings.Join(children, ","))

				client.responses[groovyDirURL] = mockResponse{body: dirJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("4.0.3"))
				Expect(versions[9].Ref).To(Equal("4.0.12"))
			})
		})

		Context("when no stable versions are found", func() {
			It("returns an error", func() {
				dirJSON := `{"children": [
					{"uri": "/apache-groovy-binary-4.0.0-alpha-1.zip", "folder": false}
				]}`

				client.responses[groovyDirURL] = mockResponse{body: dirJSON, status: 200}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no Groovy versions found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch Groovy file list"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("returns the release with download URL and SHA256 from Artifactory metadata", func() {
				metaJSON := `{
					"checksums": {"sha256": "f03e8838b56c202d8c864d462f6117d3512fdb6d1db9afcd47dfd1af81683f50"},
					"downloadUri": "https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.32.zip"
				}`

				client.responses[groovyMetaBase+"/apache-groovy-binary-4.0.32.zip"] = mockResponse{body: metaJSON, status: 200}

				release, err := watcher.In("4.0.32")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("4.0.32"))
				Expect(release.URL).To(Equal(groovyDlBase + "/apache-groovy-binary-4.0.32.zip"))
				Expect(release.SHA256).To(Equal("f03e8838b56c202d8c864d462f6117d3512fdb6d1db9afcd47dfd1af81683f50"))
			})
		})

		Context("when metadata has no SHA256", func() {
			It("returns an error", func() {
				metaJSON := `{"checksums": {}}`

				client.responses[groovyMetaBase+"/apache-groovy-binary-4.0.32.zip"] = mockResponse{body: metaJSON, status: 200}

				_, err := watcher.In("4.0.32")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no SHA256 found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("4.0.32")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch Groovy metadata"))
			})
		})
	})
})
