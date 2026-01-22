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

type mockCaApmAgentClient struct {
	responses map[string]mockResponse
}

func (m *mockCaApmAgentClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}

	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockCaApmAgentClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("CaApmAgentWatcher", func() {
	var (
		client  *mockCaApmAgentClient
		watcher *watchers.CaApmAgentWatcher
	)

	BeforeEach(func() {
		client = &mockCaApmAgentClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewCaApmAgentWatcher(client)
	})

	Describe("Check", func() {
		Context("when the artifactory page returns valid HTML", func() {
			It("returns sorted versions", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/apm_agents.html")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://packages.broadcom.com/artifactory/apm-agents/"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("10.6.0"))
				Expect(versions[1].Ref).To(Equal("10.7.0"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				html := `<html><body>
<pre><a href="CA-APM-PHPAgent-10.0.0_linux.tar.gz">CA-APM-PHPAgent-10.0.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.1.0_linux.tar.gz">CA-APM-PHPAgent-10.1.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.2.0_linux.tar.gz">CA-APM-PHPAgent-10.2.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.3.0_linux.tar.gz">CA-APM-PHPAgent-10.3.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.4.0_linux.tar.gz">CA-APM-PHPAgent-10.4.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.5.0_linux.tar.gz">CA-APM-PHPAgent-10.5.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.6.0_linux.tar.gz">CA-APM-PHPAgent-10.6.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.7.0_linux.tar.gz">CA-APM-PHPAgent-10.7.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.8.0_linux.tar.gz">CA-APM-PHPAgent-10.8.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-10.9.0_linux.tar.gz">CA-APM-PHPAgent-10.9.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-11.0.0_linux.tar.gz">CA-APM-PHPAgent-11.0.0_linux.tar.gz</a></pre>
<pre><a href="CA-APM-PHPAgent-11.1.0_linux.tar.gz">CA-APM-PHPAgent-11.1.0_linux.tar.gz</a></pre>
</body></html>`

				client.responses["https://packages.broadcom.com/artifactory/apm-agents/"] = mockResponse{
					body:   html,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("10.2.0"))
				Expect(versions[9].Ref).To(Equal("11.1.0"))
			})
		})

		Context("when no CA-APM-PHPAgent packages are found", func() {
			It("returns an error", func() {
				html := `<html><body>
<pre><a href="IntroscopeAgentFiles-NoInstaller10.0.0_16default.unix.tar">IntroscopeAgentFiles-NoInstaller10.0.0_16default.unix.tar</a></pre>
</body></html>`

				client.responses["https://packages.broadcom.com/artifactory/apm-agents/"] = mockResponse{
					body:   html,
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not parse CA APM agents website"))
			})
		})

		Context("when the HTML cannot be parsed", func() {
			It("returns an error", func() {
				client.responses["https://packages.broadcom.com/artifactory/apm-agents/"] = mockResponse{
					body:   "invalid html",
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch CA APM agents page"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific CA APM agent version", func() {
			It("returns the release details with computed SHA256", func() {
				client.responses["https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz"] = mockResponse{
					body:   "hello",
					status: 200,
				}

				release, err := watcher.In("10.6.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("10.6.0"))
				Expect(release.URL).To(Equal("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz"))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when fetching version 10.7.0", func() {
			It("constructs the correct URL", func() {
				client.responses["https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.7.0_linux.tar.gz"] = mockResponse{
					body:   "test content",
					status: 200,
				}

				release, err := watcher.In("10.7.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("10.7.0"))
				Expect(release.URL).To(Equal("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.7.0_linux.tar.gz"))
				Expect(release.SHA256).To(HaveLen(64))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.In("10.6.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download CA APM agent"))
			})
		})
	})
})
