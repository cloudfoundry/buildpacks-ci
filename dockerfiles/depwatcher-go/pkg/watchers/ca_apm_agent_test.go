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
		Context("when the Artifactory API returns releases successfully", func() {
			It("returns sorted versions from API", func() {
				apiJSON := `{
					"children": [
						{"uri": "/.index", "folder": true},
						{"uri": "/CA-APM-PHPAgent-10.6.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.7.0_linux.tar.gz", "folder": false},
						{"uri": "/25.4.1.14", "folder": true}
					]
				}`

				client.responses["https://packages.broadcom.com/artifactory/api/storage/apm-agents/"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("10.6.0"))
				Expect(versions[1].Ref).To(Equal("10.7.0"))
			})

			It("filters out non-PHP-agent files", func() {
				apiJSON := `{
					"children": [
						{"uri": "/CA-APM-PHPAgent-10.6.0_linux.tar.gz", "folder": false},
						{"uri": "/IntroscopeAgentFiles-NoInstaller10.0.0.tar", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.7.0_linux.tar.gz", "folder": false},
						{"uri": "/AXAAndriodBindings.2023.7.1.nupkg", "folder": false}
					]
				}`

				client.responses["https://packages.broadcom.com/artifactory/api/storage/apm-agents/"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("10.6.0"))
				Expect(versions[1].Ref).To(Equal("10.7.0"))
			})

			It("filters out folders", func() {
				apiJSON := `{
					"children": [
						{"uri": "/25.4.1.14", "folder": true},
						{"uri": "/CA-APM-PHPAgent-10.6.0_linux.tar.gz", "folder": false},
						{"uri": "/node-agents", "folder": true}
					]
				}`

				client.responses["https://packages.broadcom.com/artifactory/api/storage/apm-agents/"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("10.6.0"))
			})
		})

		Context("when the API returns more than 10 versions", func() {
			It("returns only the last 10 versions (API)", func() {
				apiJSON := `{
					"children": [
						{"uri": "/CA-APM-PHPAgent-10.0.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.1.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.2.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.3.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.4.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.5.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.6.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.7.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.8.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-10.9.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-11.0.0_linux.tar.gz", "folder": false},
						{"uri": "/CA-APM-PHPAgent-11.1.0_linux.tar.gz", "folder": false}
					]
				}`

				client.responses["https://packages.broadcom.com/artifactory/api/storage/apm-agents/"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("10.2.0"))
				Expect(versions[9].Ref).To(Equal("11.1.0"))
			})
		})

		Context("when the API request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch Artifactory API"))
			})
		})

		Context("when the API returns no versions", func() {
			It("returns an error", func() {
				apiJSON := `{"children": []}`

				client.responses["https://packages.broadcom.com/artifactory/api/storage/apm-agents/"] = mockResponse{
					body:   apiJSON,
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no CA APM PHP agent versions found"))
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
