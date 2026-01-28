package watchers_test

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockHttpdClient struct {
	responses   map[string]string
	statusCodes map[string]int
	callCount   map[string]int
}

func (m *mockHttpdClient) Get(url string) (*http.Response, error) {
	m.callCount[url]++

	statusCode := m.statusCodes[url]
	if statusCode == 0 {
		statusCode = 200
	}

	body, ok := m.responses[url]
	if !ok && statusCode == 200 {
		return &http.Response{
			StatusCode: 404,
			Body:       io.NopCloser(strings.NewReader("not found")),
		}, fmt.Errorf("URL not mocked: %s", url)
	}

	return &http.Response{
		StatusCode: statusCode,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func (m *mockHttpdClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockHttpdClient() *mockHttpdClient {
	return &mockHttpdClient{
		responses:   make(map[string]string),
		statusCodes: make(map[string]int),
		callCount:   make(map[string]int),
	}
}

var _ = Describe("HttpdWatcher", func() {
	var (
		watcher    *watchers.HttpdWatcher
		mockClient *mockHttpdClient
	)

	Describe("Check", func() {
		Context("when GitHub has httpd version tags", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "2.4.57", "commit": {"sha": "abc123"}},
					{"name": "2.4.58", "commit": {"sha": "def456"}},
					{"name": "2.4.59", "commit": {"sha": "ghi789"}},
					{"name": "2.5.0", "commit": {"sha": "jkl012"}},
					{"name": "some-branch", "commit": {"sha": "xyz999"}}
				]`
				mockClient = newMockHttpdClient()
				mockClient.responses["https://api.github.com/repos/apache/httpd/tags?per_page=1000"] = tags
				watcher = watchers.NewHttpdWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("2.4.57"))
				Expect(versions[1].Ref).To(Equal("2.4.58"))
				Expect(versions[2].Ref).To(Equal("2.4.59"))
				Expect(versions[3].Ref).To(Equal("2.5.0"))
			})

			It("filters out non-version tags", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+$`))
					Expect(v.Ref).NotTo(Equal("some-branch"))
				}
			})
		})

		Context("when GitHub API fails", func() {
			BeforeEach(func() {
				mockClient = newMockHttpdClient()
				watcher = watchers.NewHttpdWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching httpd tags"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific httpd version", func() {
			BeforeEach(func() {
				shaContent := "abc123def456789  httpd-2.4.59.tar.bz2\n"
				mockClient = newMockHttpdClient()
				mockClient.responses["https://archive.apache.org/dist/httpd/httpd-2.4.59.tar.bz2.sha256"] = shaContent
				watcher = watchers.NewHttpdWatcher(mockClient)
			})

			It("returns the correct download URL", func() {
				release, err := watcher.In("2.4.59")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://dlcdn.apache.org/httpd/httpd-2.4.59.tar.bz2"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("2.4.59")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("2.4.59"))
			})

			It("extracts SHA256 from Apache format", func() {
				release, err := watcher.In("2.4.59")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123def456789"))
			})
		})

		Context("when SHA256 file fetch succeeds after retries", func() {
			BeforeEach(func() {
				shaContent := "def789abc123  httpd-2.4.58.tar.bz2\n"
				mockClient = newMockHttpdClient()
				url := "https://archive.apache.org/dist/httpd/httpd-2.4.58.tar.bz2.sha256"
				mockClient.responses[url] = shaContent
				mockClient.statusCodes[url] = 500
				watcher = watchers.NewHttpdWatcherWithRetry(mockClient, 1*time.Millisecond, 3)
			})

			It("retries and eventually succeeds", func() {
				mockClient.statusCodes["https://archive.apache.org/dist/httpd/httpd-2.4.58.tar.bz2.sha256"] = 200

				release, err := watcher.In("2.4.58")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("def789abc123"))
			})
		})

		Context("when SHA256 file cannot be fetched after retries", func() {
			BeforeEach(func() {
				mockClient = newMockHttpdClient()
				mockClient.statusCodes["https://archive.apache.org/dist/httpd/httpd-2.4.59.tar.bz2.sha256"] = 404
				mockClient.responses["https://archive.apache.org/dist/httpd/httpd-2.4.59.tar.bz2.sha256"] = "not found"
				watcher = watchers.NewHttpdWatcherWithRetry(mockClient, 1*time.Millisecond, 3)
			})

			It("returns an error after max retries", func() {
				_, err := watcher.In("2.4.59")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch SHA256"))
				Expect(err.Error()).To(ContainSubstring("3 attempts"))
			})

			It("retries exactly 3 times", func() {
				watcher.In("2.4.59")
				Expect(mockClient.callCount["https://archive.apache.org/dist/httpd/httpd-2.4.59.tar.bz2.sha256"]).To(Equal(3))
			})
		})
	})
})
