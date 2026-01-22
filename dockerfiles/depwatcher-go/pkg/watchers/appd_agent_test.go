package watchers_test

import (
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockAppdAgentClient struct {
	responses map[string]mockResponse
}

func (m *mockAppdAgentClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}

	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockAppdAgentClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("AppdAgentWatcher", func() {
	var (
		client  *mockAppdAgentClient
		watcher *watchers.AppdAgentWatcher
	)

	BeforeEach(func() {
		client = &mockAppdAgentClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewAppdAgentWatcher(client)
	})

	Describe("Check", func() {
		Context("when the index returns valid YAML", func() {
			It("returns sorted versions with calendar versioning", func() {
				fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/appd_agent.yml")
				Expect(err).NotTo(HaveOccurred())

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   string(fixtureData),
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("1.1.1-2"))
				Expect(versions[1].Ref).To(Equal("1.1.1-3"))
				Expect(versions[2].Ref).To(Equal("2.1.1-1"))
				Expect(versions[3].Ref).To(Equal("3.1.1-14"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				yaml := `1.1.1_1: https://example.com/1.1.1-1.tar.bz2
1.1.1_2: https://example.com/1.1.1-2.tar.bz2
2.1.1_1: https://example.com/2.1.1-1.tar.bz2
3.1.1_1: https://example.com/3.1.1-1.tar.bz2
4.1.1_1: https://example.com/4.1.1-1.tar.bz2
5.1.1_1: https://example.com/5.1.1-1.tar.bz2
6.1.1_1: https://example.com/6.1.1-1.tar.bz2
7.1.1_1: https://example.com/7.1.1-1.tar.bz2
8.1.1_1: https://example.com/8.1.1-1.tar.bz2
9.1.1_1: https://example.com/9.1.1-1.tar.bz2
10.1.1_1: https://example.com/10.1.1-1.tar.bz2
11.1.1_1: https://example.com/11.1.1-1.tar.bz2
12.1.1_1: https://example.com/12.1.1-1.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("3.1.1-1"))
				Expect(versions[9].Ref).To(Equal("12.1.1-1"))
			})
		})

		Context("when calendar versioning sorts correctly", func() {
			It("sorts by major, minor, patch, and metadata fields", func() {
				yaml := `22.1.0_1: https://example.com/22.1.0-1.tar.bz2
22.1.0_14: https://example.com/22.1.0-14.tar.bz2
22.1.0_2: https://example.com/22.1.0-2.tar.bz2
22.2.0_1: https://example.com/22.2.0-1.tar.bz2
23.1.0_1: https://example.com/23.1.0-1.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(5))
				Expect(versions[0].Ref).To(Equal("22.1.0-1"))
				Expect(versions[1].Ref).To(Equal("22.1.0-2"))
				Expect(versions[2].Ref).To(Equal("22.1.0-14"))
				Expect(versions[3].Ref).To(Equal("22.2.0-1"))
				Expect(versions[4].Ref).To(Equal("23.1.0-1"))
			})
		})

		Context("when the YAML is empty", func() {
			It("returns an error", func() {
				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   "",
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions found"))
			})
		})

		Context("when the YAML cannot be parsed", func() {
			It("returns an error", func() {
				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   "invalid: yaml: structure:",
					status: 200,
				}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to parse index YAML"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch AppDynamics agent index"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific AppDynamics agent version", func() {
			It("returns the release details with computed SHA256", func() {
				yaml := `3.1.1_14: https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}
				client.responses["https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2"] = mockResponse{
					body:   "some-content-4",
					status: 200,
				}

				release, err := watcher.In("3.1.1-14")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.1.1-14"))
				Expect(release.URL).To(Equal("https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2"))

				expectedHash := fmt.Sprintf("%x", sha256.Sum256([]byte("some-content-4")))
				Expect(release.SHA256).To(Equal(expectedHash))
			})
		})

		Context("when fetching version 1.1.1-2", func() {
			It("converts hyphen to underscore for YAML lookup", func() {
				yaml := `1.1.1_2: https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}
				client.responses["https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2"] = mockResponse{
					body:   "some-content-1",
					status: 200,
				}

				release, err := watcher.In("1.1.1-2")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2"))
			})
		})

		Context("when the version is not found in index", func() {
			It("returns an error", func() {
				yaml := `1.1.1_2: https://example.com/1.1.1-2.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}

				_, err := watcher.In("9.9.9-99")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version 9.9.9-99 not found in index"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				yaml := `1.1.1_2: https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2`

				client.responses["https://download.run.pivotal.io/appdynamics-php/index.yml"] = mockResponse{
					body:   yaml,
					status: 200,
				}

				_, err := watcher.In("1.1.1-2")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download AppDynamics agent"))
			})
		})

		Context("when the index fetch fails", func() {
			It("returns an error", func() {
				client.responses = make(map[string]mockResponse)

				_, err := watcher.In("1.1.1-2")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch AppDynamics agent index"))
			})
		})
	})
})
