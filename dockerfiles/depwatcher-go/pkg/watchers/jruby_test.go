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

type mockJRubyClient struct {
	responses map[string]string
}

func (m *mockJRubyClient) Get(url string) (*http.Response, error) {
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

func (m *mockJRubyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockJRubyClient() *mockJRubyClient {
	return &mockJRubyClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("JRubyWatcher", func() {
	var (
		watcher    *watchers.JRubyWatcher
		mockClient *mockJRubyClient
	)

	Describe("Check", func() {
		Context("when GitHub API returns releases successfully", func() {
			BeforeEach(func() {
				apiJSON := `[
					{"tag_name":"9.4.0.0","prerelease":false,"assets":[]},
					{"tag_name":"9.3.10.0","prerelease":false,"assets":[]},
					{"tag_name":"9.3.0.0","prerelease":false,"assets":[]},
					{"tag_name":"9.2.20.0","prerelease":false,"assets":[]}
				]`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://api.github.com/repos/jruby/jruby/releases?per_page=100"] = apiJSON
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("9.2.20.0"))
				Expect(versions[1].Ref).To(Equal("9.3.0.0"))
				Expect(versions[2].Ref).To(Equal("9.3.10.0"))
				Expect(versions[3].Ref).To(Equal("9.4.0.0"))
			})

			It("extracts version from tag names", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+\.\d+$`))
				}
			})
		})

		Context("when GitHub API returns pre-releases", func() {
			BeforeEach(func() {
				apiJSON := `[
					{"tag_name":"10.0.0","prerelease":false,"assets":[]},
					{"tag_name":"10.0.0-rc1","prerelease":true,"assets":[]},
					{"tag_name":"9.4.0.0","prerelease":false,"assets":[]}
				]`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://api.github.com/repos/jruby/jruby/releases?per_page=100"] = apiJSON
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("filters out pre-releases", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("9.4.0.0"))
				Expect(versions[1].Ref).To(Equal("10.0.0"))
			})
		})

		Context("when GitHub API request fails", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching GitHub releases"))
			})
		})

		Context("when GitHub API returns no versions", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				mockClient.responses["https://api.github.com/repos/jruby/jruby/releases?per_page=100"] = "[]"
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions found"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific JRuby version from GitHub", func() {
			BeforeEach(func() {
				releaseJSON := `{
					"tag_name":"9.4.0.0",
					"prerelease":false,
					"assets":[
						{"name":"jruby-src-9.4.0.0.zip","browser_download_url":"https://github.com/jruby/jruby/releases/download/9.4.0.0/jruby-src-9.4.0.0.zip"}
					]
				}`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://api.github.com/repos/jruby/jruby/releases/tags/9.4.0.0"] = releaseJSON
				mockClient.responses["https://github.com/jruby/jruby/releases/download/9.4.0.0/jruby-src-9.4.0.0.zip"] = "fake-zip-content"
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns the correct GitHub download URL", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://github.com/jruby/jruby/releases/download/9.4.0.0/jruby-src-9.4.0.0.zip"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("9.4.0.0"))
			})

			It("calculates SHA256", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when GitHub release is not found (fallback to Maven)", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				mockClient.responses["https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip"] = "fake-zip-content"
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("falls back to Maven URL", func() {
				release, err := watcher.In("9.3.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip"))
			})

			It("calculates SHA256 from Maven source", func() {
				release, err := watcher.In("9.3.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})
	})
})
