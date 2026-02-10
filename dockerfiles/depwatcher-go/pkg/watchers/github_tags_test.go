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

type mockGithubTagsClient struct {
	responses      map[string]string
	downloadBodies map[string]string
}

func (m *mockGithubTagsClient) Get(url string) (*http.Response, error) {
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

func (m *mockGithubTagsClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockGithubTagsClient(tags string) *mockGithubTagsClient {
	return &mockGithubTagsClient{
		responses: map[string]string{
			"https://api.github.com/repos/test/repo/tags?per_page=1000": tags,
		},
		downloadBodies: make(map[string]string),
	}
}

var _ = Describe("GithubTagsWatcher", func() {
	var (
		watcher    *watchers.GithubTagsWatcher
		mockClient *mockGithubTagsClient
	)

	Describe("Check", func() {
		Context("when there are multiple tags", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}},
					{"name": "v2.0.0", "commit": {"sha": "def456"}},
					{"name": "v1.5.0", "commit": {"sha": "ghi789"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns all tags sorted by semver", func() {
				versions, err := watcher.Check(".*")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("v1.0.0"))
				Expect(versions[1].Ref).To(Equal("v1.5.0"))
				Expect(versions[2].Ref).To(Equal("v2.0.0"))
			})

			It("does not strip 'v' prefix", func() {
				versions, err := watcher.Check(".*")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions[0].Ref).To(Equal("v1.0.0"))
			})
		})

		Context("when filtering tags by regex", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}},
					{"name": "v2.0.0", "commit": {"sha": "def456"}},
					{"name": "release-3.0.0", "commit": {"sha": "ghi789"}},
					{"name": "v1.5.0-beta", "commit": {"sha": "jkl012"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns only tags matching the regex", func() {
				versions, err := watcher.Check("^v\\d+\\.\\d+\\.\\d+$")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("v1.0.0"))
				Expect(versions[1].Ref).To(Equal("v2.0.0"))
			})
		})

		Context("when filtering Ruby tags (v3_2_0 format)", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v3_2_0", "commit": {"sha": "abc123"}},
					{"name": "v3_2_1", "commit": {"sha": "def456"}},
					{"name": "v3_1_0", "commit": {"sha": "ghi789"}},
					{"name": "v3_2_0_preview1", "commit": {"sha": "jkl012"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns only tags matching exact pattern", func() {
				versions, err := watcher.Check("^v\\d+_\\d+_\\d+$")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("v3_1_0"))
				Expect(versions[1].Ref).To(Equal("v3_2_0"))
				Expect(versions[2].Ref).To(Equal("v3_2_1"))
			})

			It("filters out preview releases", func() {
				versions, err := watcher.Check("^v\\d+_\\d+_\\d+$")
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(ContainSubstring("preview"))
				}
			})
		})

		Context("when no tags match the regex", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "release-1.0.0", "commit": {"sha": "abc123"}},
					{"name": "release-2.0.0", "commit": {"sha": "def456"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns an empty list", func() {
				versions, err := watcher.Check("^v\\d+\\.\\d+\\.\\d+$")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(0))
			})
		})

		Context("when the regex is invalid", func() {
			BeforeEach(func() {
				tags := `[{"name": "v1.0.0", "commit": {"sha": "abc123"}}]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns an error", func() {
				_, err := watcher.Check("(invalid")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("compiling regex"))
			})
		})

		Context("when versions cannot be parsed as semver", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}},
					{"name": "notasemver", "commit": {"sha": "def456"}},
					{"name": "v2.0.0", "commit": {"sha": "ghi789"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("falls back to lexicographic sorting for non-semver tags", func() {
				versions, err := watcher.Check(".*")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				// Lexicographic sort: notasemver < v1.0.0 < v2.0.0
				Expect(versions[0].Ref).To(Equal("notasemver"))
				Expect(versions[1].Ref).To(Equal("v1.0.0"))
				Expect(versions[2].Ref).To(Equal("v2.0.0"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific tag", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.2.3", "commit": {"sha": "abc123def456"}},
					{"name": "v1.2.4", "commit": {"sha": "def456ghi789"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				mockClient.downloadBodies["https://github.com/test/repo/archive/abc123def456.tar.gz"] = "archive-content"
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns the tag details with commit SHA", func() {
				tag, err := watcher.In("v1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(tag.Ref).To(Equal("v1.2.3"))
				Expect(tag.GitCommitSHA).To(Equal("abc123def456"))
			})

			It("constructs the archive URL using the commit SHA", func() {
				tag, err := watcher.In("v1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(tag.URL).To(Equal("https://github.com/test/repo/archive/abc123def456.tar.gz"))
			})

			It("calculates the SHA256 of the archive", func() {
				tag, err := watcher.In("v1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(tag.SHA256).NotTo(BeEmpty())
				Expect(tag.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when the tag is not found", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns an error", func() {
				_, err := watcher.In("v2.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find data for version v2.0.0"))
			})
		})

		Context("when downloading fails", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				// Don't set up downloadBodies, so download will fail
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns an error", func() {
				_, err := watcher.In("v1.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("calculating SHA256"))
			})
		})
	})

	Describe("MatchedTags", func() {
		Context("when called directly", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v1.0.0", "commit": {"sha": "abc123"}},
					{"name": "v2.0.0", "commit": {"sha": "def456"}},
					{"name": "release-3.0.0", "commit": {"sha": "ghi789"}}
				]`
				mockClient = newMockGithubTagsClient(tags)
				watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
			})

			It("returns matched tags with commit information", func() {
				matched, err := watcher.MatchedTags("^v\\d+\\.\\d+\\.\\d+$")
				Expect(err).NotTo(HaveOccurred())
				Expect(matched).To(HaveLen(2))
				Expect(matched[0].Name).To(Equal("v1.0.0"))
				Expect(matched[0].Commit.SHA).To(Equal("abc123"))
				Expect(matched[1].Name).To(Equal("v2.0.0"))
				Expect(matched[1].Commit.SHA).To(Equal("def456"))
			})
		})
	})

	Describe("SHA256 Calculation", func() {
		BeforeEach(func() {
			tags := `[
				{"name": "v1.0.0", "commit": {"sha": "abc123def456"}}
			]`
			mockClient = newMockGithubTagsClient(tags)
			mockClient.downloadBodies["https://github.com/test/repo/archive/abc123def456.tar.gz"] = "test-content"
			watcher = watchers.NewGithubTagsWatcher(mockClient, "test/repo")
		})

		It("calculates SHA256 of downloaded archive", func() {
			tag, err := watcher.In("v1.0.0")
			Expect(err).NotTo(HaveOccurred())
			Expect(tag.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
		})
	})
})
