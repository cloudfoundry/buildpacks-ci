package watchers_test

import (
	"io"
	"net/http"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type adoptOpenJDKMockClient struct {
	response *http.Response
	err      error
}

func (m *adoptOpenJDKMockClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.response, nil
}

func (m *adoptOpenJDKMockClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("AdoptOpenJDKWatcher", func() {
	var (
		watcher    *watchers.AdoptOpenJDKWatcher
		mockClient *adoptOpenJDKMockClient
	)

	BeforeEach(func() {
		mockClient = &adoptOpenJDKMockClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid JSON", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"binaries": [
								{
									"package": {
										"link": "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.16%2B8/OpenJDK11U-jdk_x64_linux_hotspot_11.0.16_8.tar.gz"
									}
								}
							],
							"version_data": {
								"semver": "11.0.16+8"
							}
						},
						{
							"binaries": [
								{
									"package": {
										"link": "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.15_10.tar.gz"
									}
								}
							],
							"version_data": {
								"semver": "11.0.15+10"
							}
						}
					]`)),
				}
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns a list of versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("11.0.15+10"))
				Expect(versions[1].Ref).To(Equal("11.0.16+8"))
			})
		})

		Context("when version is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "", "hotspot", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version must be specified"))
			})
		})

		Context("when implementation is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("implementation must be specified"))
			})
		})

		Context("when type is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("type must be specified"))
			})
		})

		Context("when the server returns an error", func() {
			BeforeEach(func() {
				mockClient.err = http.ErrHandlerTimeout
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching AdoptOpenJDK releases"))
			})
		})

		Context("when the server returns non-200 status", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 404,
					Body:       io.NopCloser(strings.NewReader("")),
				}
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected status code 404"))
			})
		})

		Context("when the JSON is invalid", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader("invalid json")),
				}
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("parsing JSON response"))
			})
		})
	})

	Describe("In", func() {
		Context("with valid version", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"binaries": [
								{
									"package": {
										"link": "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.16%2B8/OpenJDK11U-jdk_x64_linux_hotspot_11.0.16_8.tar.gz"
									}
								}
							],
							"version_data": {
								"semver": "11.0.16+8"
							}
						}
					]`)),
				}
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns the correct download URL", func() {
				release, err := watcher.In("11.0.16+8")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("11.0.16+8"))
				Expect(release.URL).To(Equal("https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.16%2B8/OpenJDK11U-jdk_x64_linux_hotspot_11.0.16_8.tar.gz"))
			})
		})

		Context("when version not found", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader("[]")),
				}
				watcher = watchers.NewAdoptOpenJDKWatcher(mockClient, "11", "hotspot", "jdk")
			})

			It("returns an error", func() {
				_, err := watcher.In("11.0.99+99")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version 11.0.99+99 not found"))
			})
		})
	})
})
