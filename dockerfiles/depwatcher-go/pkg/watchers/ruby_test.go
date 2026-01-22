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

type mockRubyClient struct {
	responses map[string]string
}

func (m *mockRubyClient) Get(url string) (*http.Response, error) {
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

func (m *mockRubyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockRubyClient() *mockRubyClient {
	return &mockRubyClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("RubyWatcher", func() {
	var (
		watcher    *watchers.RubyWatcher
		mockClient *mockRubyClient
	)

	Describe("Check", func() {
		Context("when there are multiple Ruby tags", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v3_2_0", "commit": {"sha": "abc123"}},
					{"name": "v3_2_1", "commit": {"sha": "def456"}},
					{"name": "v3_1_0", "commit": {"sha": "ghi789"}},
					{"name": "v3_1_1", "commit": {"sha": "jkl012"}}
				]`
				mockClient = newMockRubyClient()
				mockClient.responses["https://api.github.com/repos/ruby/ruby/tags?per_page=1000"] = tags
				watcher = watchers.NewRubyWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("3.1.0"))
				Expect(versions[1].Ref).To(Equal("3.1.1"))
				Expect(versions[2].Ref).To(Equal("3.2.0"))
				Expect(versions[3].Ref).To(Equal("3.2.1"))
			})

			It("converts underscores to dots", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(ContainSubstring("_"))
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+$`))
				}
			})

			It("strips 'v' prefix", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(HavePrefix("v"))
				}
			})
		})

		Context("when there are preview releases", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v3_2_0", "commit": {"sha": "abc123"}},
					{"name": "v3_2_1_preview1", "commit": {"sha": "def456"}},
					{"name": "v3_2_2_rc1", "commit": {"sha": "ghi789"}},
					{"name": "v3_3_0", "commit": {"sha": "jkl012"}}
				]`
				mockClient = newMockRubyClient()
				mockClient.responses["https://api.github.com/repos/ruby/ruby/tags?per_page=1000"] = tags
				watcher = watchers.NewRubyWatcher(mockClient)
			})

			It("filters out preview and RC releases", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("3.2.0"))
				Expect(versions[1].Ref).To(Equal("3.3.0"))
			})
		})

		Context("when there are tags with different formats", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "v3_2_0", "commit": {"sha": "abc123"}},
					{"name": "release-1.0.0", "commit": {"sha": "def456"}},
					{"name": "v3_3_0", "commit": {"sha": "ghi789"}}
				]`
				mockClient = newMockRubyClient()
				mockClient.responses["https://api.github.com/repos/ruby/ruby/tags?per_page=1000"] = tags
				watcher = watchers.NewRubyWatcher(mockClient)
			})

			It("only returns tags matching the Ruby format", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("3.2.0"))
				Expect(versions[1].Ref).To(Equal("3.3.0"))
			})
		})
	})

	Describe("In", func() {
		BeforeEach(func() {
			mockClient = newMockRubyClient()
			watcher = watchers.NewRubyWatcher(mockClient)
		})

		Context("when release is available in releases.yml", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
  sha256:
    gz: abc123def456abc123def456abc123def456abc123def456abc123def456abc1
- version: 3.1.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.0.tar.gz
  sha256:
    gz: def456abc123def456abc123def456abc123def456abc123def456abc123def4
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
			})

			It("returns release information from releases.yml", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.2.0"))
				Expect(release.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz"))
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})

			It("does not fall back to index.txt", func() {
				_, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(mockClient.responses).NotTo(HaveKey("https://cache.ruby-lang.org/pub/ruby/index.txt"))
			})
		})

		Context("when release has missing URL in releases.yml", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  sha256:
    gz: abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
ruby-3.1.0 https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.0.tar.gz 67890 def456abc123def456abc123def456abc123def456abc123def456abc123def4
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("falls back to index.txt", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.2.0"))
				Expect(release.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz"))
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})
		})

		Context("when release has missing SHA256 in releases.yml", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("falls back to index.txt", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.2.0"))
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})
		})

		Context("when release is not in releases.yml but in index.txt", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
  sha256:
    gz: abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
ruby-3.1.0 https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.0.tar.gz 67890 def456abc123def456abc123def456abc123def456abc123def456abc123def4
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("falls back to index.txt", func() {
				release, err := watcher.In("3.1.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("3.1.0"))
				Expect(release.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.0.tar.gz"))
				Expect(release.SHA256).To(Equal("def456abc123def456abc123def456abc123def456abc123def456abc123def4"))
			})
		})

		Context("when index.txt has multiple formats for the same version", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://example.com/invalid.tar.gz
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.bz2 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 67890 def456abc123def456abc123def456abc123def456abc123def456abc123def4
ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.zip 11111 ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi7
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("returns only the tar.gz version", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz"))
				Expect(release.SHA256).To(Equal("def456abc123def456abc123def456abc123def456abc123def456abc123def4"))
			})
		})

		Context("when release is not found in either source", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
  sha256:
    gz: abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("returns an error", func() {
				_, err := watcher.In("3.3.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no release with ref: 3.3.0 found"))
			})
		})

		Context("when index.txt has lines with insufficient fields", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
`
				indexTxt := `ruby-3.2.0
ruby-3.1.0 https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.0.tar.gz
ruby-3.3.0 https://cache.ruby-lang.org/pub/ruby/3.3/ruby-3.3.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("skips invalid lines and processes valid ones", func() {
				result, err := watcher.In("3.3.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(result.Ref).To(Equal("3.3.0"))
				Expect(result.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.3/ruby-3.3.0.tar.gz"))
			})
		})

		Context("when releases.yml has empty URL map", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url: {}
  sha256:
    gz: abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("falls back to index.txt", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz"))
			})
		})

		Context("when releases.yml has empty SHA256 map", func() {
			BeforeEach(func() {
				releasesYml := `- version: 3.2.0
  url:
    gz: https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
  sha256: {}
`
				indexTxt := `ruby-3.2.0 https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz 12345 abc123def456abc123def456abc123def456abc123def456abc123def456abc1
`
				mockClient.responses["https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml"] = releasesYml
				mockClient.responses["https://cache.ruby-lang.org/pub/ruby/index.txt"] = indexTxt
			})

			It("falls back to index.txt", func() {
				release, err := watcher.In("3.2.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})
		})
	})
})
