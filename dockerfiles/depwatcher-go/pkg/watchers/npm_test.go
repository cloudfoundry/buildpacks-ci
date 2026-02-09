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

type mockNPMClient struct {
	responses map[string]string
}

func (m *mockNPMClient) Get(url string) (*http.Response, error) {
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

func (m *mockNPMClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockNPMClient() *mockNPMClient {
	return &mockNPMClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("NPMWatcher", func() {
	var (
		watcher    *watchers.NPMWatcher
		mockClient *mockNPMClient
	)

	Describe("Check", func() {
		Context("when there are multiple versions", func() {
			BeforeEach(func() {
				registryResponse := `{
					"versions": {
						"1.0.0": {
							"name": "test-package",
							"version": "1.0.0",
							"dist": {
								"shasum": "abc123",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-1.0.0.tgz"
							}
						},
						"1.0.1": {
							"name": "test-package",
							"version": "1.0.1",
							"dist": {
								"shasum": "def456",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-1.0.1.tgz"
							}
						},
						"2.0.0": {
							"name": "test-package",
							"version": "2.0.0",
							"dist": {
								"shasum": "ghi789",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-2.0.0.tgz"
							}
						}
					}
				}`
				mockClient = newMockNPMClient()
				mockClient.responses["https://registry.npmjs.com/test-package/"] = registryResponse
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check("test-package")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("1.0.1"))
				Expect(versions[2].Ref).To(Equal("2.0.0"))
			})
		})

		Context("when there are more than 10 versions", func() {
			BeforeEach(func() {
				registryResponse := `{
					"versions": {
						"1.0.0": {"name": "pkg", "version": "1.0.0", "dist": {"shasum": "a", "tarball": "https://example.com/1.0.0.tgz"}},
						"1.0.1": {"name": "pkg", "version": "1.0.1", "dist": {"shasum": "b", "tarball": "https://example.com/1.0.1.tgz"}},
						"1.0.2": {"name": "pkg", "version": "1.0.2", "dist": {"shasum": "c", "tarball": "https://example.com/1.0.2.tgz"}},
						"1.0.3": {"name": "pkg", "version": "1.0.3", "dist": {"shasum": "d", "tarball": "https://example.com/1.0.3.tgz"}},
						"1.0.4": {"name": "pkg", "version": "1.0.4", "dist": {"shasum": "e", "tarball": "https://example.com/1.0.4.tgz"}},
						"1.0.5": {"name": "pkg", "version": "1.0.5", "dist": {"shasum": "f", "tarball": "https://example.com/1.0.5.tgz"}},
						"1.0.6": {"name": "pkg", "version": "1.0.6", "dist": {"shasum": "g", "tarball": "https://example.com/1.0.6.tgz"}},
						"1.0.7": {"name": "pkg", "version": "1.0.7", "dist": {"shasum": "h", "tarball": "https://example.com/1.0.7.tgz"}},
						"1.0.8": {"name": "pkg", "version": "1.0.8", "dist": {"shasum": "i", "tarball": "https://example.com/1.0.8.tgz"}},
						"1.0.9": {"name": "pkg", "version": "1.0.9", "dist": {"shasum": "j", "tarball": "https://example.com/1.0.9.tgz"}},
						"1.0.10": {"name": "pkg", "version": "1.0.10", "dist": {"shasum": "k", "tarball": "https://example.com/1.0.10.tgz"}},
						"1.0.11": {"name": "pkg", "version": "1.0.11", "dist": {"shasum": "l", "tarball": "https://example.com/1.0.11.tgz"}},
						"2.0.0": {"name": "pkg", "version": "2.0.0", "dist": {"shasum": "m", "tarball": "https://example.com/2.0.0.tgz"}}
					}
				}`
				mockClient = newMockNPMClient()
				mockClient.responses["https://registry.npmjs.com/test-package/"] = registryResponse
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns only the last 10 versions", func() {
				versions, err := watcher.Check("test-package")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("1.0.3"))
				Expect(versions[9].Ref).To(Equal("2.0.0"))
			})
		})

		Context("when there are prerelease versions", func() {
			BeforeEach(func() {
				registryResponse := `{
					"versions": {
						"1.0.0": {"name": "pkg", "version": "1.0.0", "dist": {"shasum": "a", "tarball": "https://example.com/1.0.0.tgz"}},
						"1.0.1-beta.1": {"name": "pkg", "version": "1.0.1-beta.1", "dist": {"shasum": "b", "tarball": "https://example.com/1.0.1-beta.1.tgz"}},
						"1.0.1": {"name": "pkg", "version": "1.0.1", "dist": {"shasum": "c", "tarball": "https://example.com/1.0.1.tgz"}},
						"2.0.0-alpha": {"name": "pkg", "version": "2.0.0-alpha", "dist": {"shasum": "d", "tarball": "https://example.com/2.0.0-alpha.tgz"}},
						"2.0.0": {"name": "pkg", "version": "2.0.0", "dist": {"shasum": "e", "tarball": "https://example.com/2.0.0.tgz"}}
					}
				}`
				mockClient = newMockNPMClient()
				mockClient.responses["https://registry.npmjs.com/test-package/"] = registryResponse
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("includes prerelease versions in the results", func() {
				versions, err := watcher.Check("test-package")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(5))
			})

			It("sorts prereleases correctly", func() {
				versions, err := watcher.Check("test-package")
				Expect(err).NotTo(HaveOccurred())
				// Pre-release versions should come before release versions per semver spec
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("1.0.1-beta.1"))
				Expect(versions[2].Ref).To(Equal("1.0.1"))
				Expect(versions[3].Ref).To(Equal("2.0.0-alpha"))
				Expect(versions[4].Ref).To(Equal("2.0.0"))
			})
		})

		Context("when package does not exist", func() {
			BeforeEach(func() {
				mockClient = newMockNPMClient()
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check("nonexistent-package")
				Expect(err).To(HaveOccurred())
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			BeforeEach(func() {
				registryResponse := `{
					"versions": {
						"1.2.3": {
							"name": "test-package",
							"version": "1.2.3",
							"dist": {
								"shasum": "abc123def456",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-1.2.3.tgz"
							}
						},
						"1.2.4": {
							"name": "test-package",
							"version": "1.2.4",
							"dist": {
								"shasum": "def456ghi789",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-1.2.4.tgz"
							}
						}
					}
				}`
				mockClient = newMockNPMClient()
				mockClient.responses["https://registry.npmjs.com/test-package/"] = registryResponse
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns the release details", func() {
				release, err := watcher.In("test-package", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
				Expect(release.URL).To(Equal("https://registry.npmjs.org/test-package/-/test-package-1.2.3.tgz"))
				Expect(release.SHA1).To(Equal("abc123def456"))
			})
		})

		Context("when version does not exist", func() {
			BeforeEach(func() {
				registryResponse := `{
					"versions": {
						"1.0.0": {
							"name": "test-package",
							"version": "1.0.0",
							"dist": {
								"shasum": "abc123",
								"tarball": "https://registry.npmjs.org/test-package/-/test-package-1.0.0.tgz"
							}
						}
					}
				}`
				mockClient = newMockNPMClient()
				mockClient.responses["https://registry.npmjs.com/test-package/"] = registryResponse
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("test-package", "2.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version 2.0.0 not found"))
			})
		})

		Context("when package does not exist", func() {
			BeforeEach(func() {
				mockClient = newMockNPMClient()
				watcher = watchers.NewNPMWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("nonexistent-package", "1.0.0")
				Expect(err).To(HaveOccurred())
			})
		})
	})
})
