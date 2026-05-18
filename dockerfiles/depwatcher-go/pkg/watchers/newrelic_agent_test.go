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

type mockNewRelicAgentClient struct {
	responses map[string]mockResponse
}

func (m *mockNewRelicAgentClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockNewRelicAgentClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockNewRelicAgentClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

const indexURL = "https://download.newrelic.com/newrelic/java-agent/newrelic-agent/"

var _ = Describe("NewRelicAgentWatcher", func() {
	var (
		client  *mockNewRelicAgentClient
		watcher *watchers.NewRelicAgentWatcher
	)

	BeforeEach(func() {
		client = &mockNewRelicAgentClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewNewRelicAgentWatcher(client)
	})

	Describe("Check", func() {
		Context("when the index page lists versions", func() {
			It("returns sorted versions", func() {
				indexHTML := `<html><body>
<a href="9.1.0/">9.1.0/</a>
<a href="9.2.0/">9.2.0/</a>
<a href="8.25.1/">8.25.1/</a>
<a href="current">current</a>
</body></html>`

				client.responses[indexURL] = mockResponse{body: indexHTML, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("8.25.1"))
				Expect(versions[1].Ref).To(Equal("9.1.0"))
				Expect(versions[2].Ref).To(Equal("9.2.0"))
			})

			It("skips non-version links", func() {
				indexHTML := `<html><body>
<a href="..">Parent</a>
<a href="current">current</a>
<a href="9.2.0/">9.2.0/</a>
</body></html>`

				client.responses[indexURL] = mockResponse{body: indexHTML, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("9.2.0"))
			})
		})

		Context("when the index contains more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				var links strings.Builder
				for i := 1; i <= 12; i++ {
					links.WriteString(fmt.Sprintf(`<a href="9.%d.0/">9.%d.0/</a>`, i, i))
				}
				indexHTML := fmt.Sprintf("<html><body>%s</body></html>", links.String())

				client.responses[indexURL] = mockResponse{body: indexHTML, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("9.3.0"))
				Expect(versions[9].Ref).To(Equal("9.12.0"))
			})
		})

		Context("when no versions are found", func() {
			It("returns an error", func() {
				client.responses[indexURL] = mockResponse{body: "<html><body></body></html>", status: 200}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no New Relic Java agent versions found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch New Relic agent index"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("returns the release with URL and computed SHA256", func() {
				jarURL := indexURL + "9.2.0/newrelic-agent-9.2.0.jar"
				client.responses[jarURL] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("9.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("9.2.0"))
				Expect(release.URL).To(Equal(jarURL))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("9.2.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download New Relic agent"))
			})
		})
	})
})
