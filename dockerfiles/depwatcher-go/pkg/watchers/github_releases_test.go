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

type mockGithubReleasesClient struct {
	responses      map[string]string
	headers        map[string]http.Header
	downloadBodies map[string]string
}

func (m *mockGithubReleasesClient) Get(url string) (*http.Response, error) {
	body, ok := m.responses[url]
	if !ok {
		downloadBody, hasDownload := m.downloadBodies[url]
		if !hasDownload {
			return &http.Response{
				StatusCode: 404,
				Body:       io.NopCloser(strings.NewReader("not found")),
			}, fmt.Errorf("URL not mocked: %s", url)
		}
		body = downloadBody
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func (m *mockGithubReleasesClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	m.headers[url] = headers

	body, ok := m.downloadBodies[url]
	if !ok {
		body = "mock-file-content"
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func newMockGithubReleasesClient(releases string) *mockGithubReleasesClient {
	return &mockGithubReleasesClient{
		responses: map[string]string{
			"https://api.github.com/repos/test/repo/releases": releases,
		},
		headers:        make(map[string]http.Header),
		downloadBodies: make(map[string]string),
	}
}

var _ = Describe("GithubReleasesWatcher", func() {
	var (
		watcher    *watchers.GithubReleasesWatcher
		mockClient *mockGithubReleasesClient
	)

	Describe("Check", func() {
		Context("when there are multiple releases", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v2.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v1.5.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("1.5.0"))
				Expect(versions[2].Ref).To(Equal("2.0.0"))
			})

			It("strips 'v' prefix from tag names", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[0].Ref).NotTo(ContainSubstring("v"))
			})
		})

		Context("when there are draft releases", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v2.0.0", "draft": true, "prerelease": false, "assets": []},
					{"tag_name": "v3.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
			})

			It("filters out draft releases", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("3.0.0"))
			})
		})

		Context("when there are prerelease versions", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v2.0.0-beta.1", "draft": false, "prerelease": true, "assets": []},
					{"tag_name": "v3.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
			})

			Context("when allow_prerelease is false", func() {
				BeforeEach(func() {
					watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
				})

				It("filters out prereleases", func() {
					versions, err := watcher.Check()
					Expect(err).NotTo(HaveOccurred())
					Expect(versions).To(HaveLen(2))
					Expect(versions[0].Ref).To(Equal("1.0.0"))
					Expect(versions[1].Ref).To(Equal("3.0.0"))
				})
			})

			Context("when allow_prerelease is true", func() {
				BeforeEach(func() {
					watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", true)
				})

				It("still filters out versions with alphabetic suffixes", func() {
					versions, err := watcher.Check()
					Expect(err).NotTo(HaveOccurred())
					Expect(versions).To(HaveLen(2))
					Expect(versions[0].Ref).To(Equal("1.0.0"))
					Expect(versions[1].Ref).To(Equal("3.0.0"))
				})
			})
		})

		Context("when versions have alphabetic suffixes", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v2.0.0alpha", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v3.0.0rc1", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v4.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
			})

			It("filters out versions with alphabetic suffixes", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("4.0.0"))
			})
		})

		Context("when tag_name is empty after stripping 'v'", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
			})

			It("filters out empty refs", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
			})
		})

		Context("when versions cannot be parsed as semver", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []},
					{"tag_name": "v2.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false)
			})

			It("sorts versions by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("2.0.0"))
			})
		})
	})

	Describe("In", func() {
		Context("when downloading an asset by extension", func() {
			BeforeEach(func() {
				releases := `[
					{
						"tag_name": "v1.2.3",
						"draft": false,
						"prerelease": false,
						"assets": [
							{
								"name": "binary.tar.gz",
								"browser_download_url": "https://github.com/test/repo/releases/download/v1.2.3/binary.tar.gz"
							},
							{
								"name": "binary.zip",
								"browser_download_url": "https://github.com/test/repo/releases/download/v1.2.3/binary.zip"
							}
						]
					}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				mockClient.downloadBodies["https://github.com/test/repo/releases/download/v1.2.3/binary.tar.gz"] = "archive-content"
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithExtension(".tar.gz")
			})

			It("downloads the asset with the specified extension", func() {
				release, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
				Expect(release.URL).To(Equal("https://github.com/test/repo/releases/download/v1.2.3/binary.tar.gz"))
				Expect(release.SHA256).NotTo(BeEmpty())
			})

			It("uses 'Accept: application/octet-stream' header", func() {
				_, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())

				headers := mockClient.headers["https://github.com/test/repo/releases/download/v1.2.3/binary.tar.gz"]
				Expect(headers).To(HaveKey("Accept"))
				Expect(headers["Accept"]).To(ContainElement("application/octet-stream"))
			})
		})

		Context("when there are multiple assets with the same extension", func() {
			BeforeEach(func() {
				releases := `[
					{
						"tag_name": "v1.2.3",
						"draft": false,
						"prerelease": false,
						"assets": [
							{
								"name": "binary-linux.tar.gz",
								"browser_download_url": "https://github.com/test/repo/releases/download/v1.2.3/binary-linux.tar.gz"
							},
							{
								"name": "binary-darwin.tar.gz",
								"browser_download_url": "https://github.com/test/repo/releases/download/v1.2.3/binary-darwin.tar.gz"
							}
						]
					}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithExtension(".tar.gz")
			})

			It("returns an error", func() {
				_, err := watcher.In("1.2.3")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("expected 1 asset with extension .tar.gz, found 2"))
			})
		})

		Context("when there are no assets with the specified extension", func() {
			BeforeEach(func() {
				releases := `[
					{
						"tag_name": "v1.2.3",
						"draft": false,
						"prerelease": false,
						"assets": [
							{
								"name": "binary.zip",
								"browser_download_url": "https://github.com/test/repo/releases/download/v1.2.3/binary.zip"
							}
						]
					}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithExtension(".tar.gz")
			})

			It("returns an error", func() {
				_, err := watcher.In("1.2.3")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("expected 1 asset with extension .tar.gz, found 0"))
			})
		})

		Context("when downloading source archive", func() {
			BeforeEach(func() {
				releases := `[
					{
						"tag_name": "v1.2.3",
						"draft": false,
						"prerelease": false,
						"assets": []
					}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				mockClient.downloadBodies["https://github.com/test/repo/archive/v1.2.3.tar.gz"] = "source-archive-content"
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithFetchSource(true)
			})

			It("downloads the source archive", func() {
				release, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
				Expect(release.URL).To(Equal("https://github.com/test/repo/archive/v1.2.3.tar.gz"))
				Expect(release.SHA256).NotTo(BeEmpty())
			})

			It("uses the original tag_name with 'v' prefix in the URL", func() {
				release, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(ContainSubstring("/archive/v1.2.3.tar.gz"))
			})
		})

		Context("when the version is not found", func() {
			BeforeEach(func() {
				releases := `[
					{"tag_name": "v1.0.0", "draft": false, "prerelease": false, "assets": []}
				]`
				mockClient = newMockGithubReleasesClient(releases)
				watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithExtension(".tar.gz")
			})

			It("returns an error", func() {
				_, err := watcher.In("2.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find release data for version 2.0.0"))
			})
		})
	})

	Describe("Builder Pattern", func() {
		It("allows chaining WithExtension and WithFetchSource", func() {
			mockClient = newMockGithubReleasesClient("[]")
			watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).
				WithExtension(".tar.gz").
				WithFetchSource(false)

			Expect(watcher).NotTo(BeNil())
		})
	})

	Describe("SHA256 Calculation", func() {
		BeforeEach(func() {
			releases := `[
				{
					"tag_name": "v1.0.0",
					"draft": false,
					"prerelease": false,
					"assets": [
						{
							"name": "test.tar.gz",
							"browser_download_url": "https://github.com/test/repo/releases/download/v1.0.0/test.tar.gz"
						}
					]
				}
			]`
			mockClient = newMockGithubReleasesClient(releases)
			mockClient.downloadBodies["https://github.com/test/repo/releases/download/v1.0.0/test.tar.gz"] = "test-content"
			watcher = watchers.NewGithubReleasesWatcher(mockClient, "test/repo", false).WithExtension(".tar.gz")
		})

		It("calculates SHA256 of downloaded file", func() {
			release, err := watcher.In("1.0.0")
			Expect(err).NotTo(HaveOccurred())
			Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
		})
	})
})
