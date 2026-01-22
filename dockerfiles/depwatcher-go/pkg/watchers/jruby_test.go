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
		Context("when JRuby download page has multiple versions", func() {
			BeforeEach(func() {
				html := `
				<html>
					<body>
						<h2>JRuby Downloads</h2>
						<ul>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip">JRuby 9.3.0.0 Source</a></li>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.0.0/jruby-dist-9.4.0.0-src.zip">JRuby 9.4.0.0 Source</a></li>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.10.0/jruby-dist-9.3.10.0-src.zip">JRuby 9.3.10.0 Source</a></li>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.2.20.0/jruby-dist-9.2.20.0-src.zip">JRuby 9.2.20.0 Source</a></li>
						</ul>
					</body>
				</html>
				`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://www.jruby.org/download"] = html
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

			It("extracts version from Maven URLs", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+\.\d+$`))
				}
			})
		})

		Context("when there are duplicate versions", func() {
			BeforeEach(func() {
				html := `
				<html>
					<body>
						<ul>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip">Source</a></li>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip">Source Again</a></li>
							<li><a href="https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.0.0/jruby-dist-9.4.0.0-src.zip">Source</a></li>
						</ul>
					</body>
				</html>
				`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://www.jruby.org/download"] = html
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("deduplicates versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("9.3.0.0"))
				Expect(versions[1].Ref).To(Equal("9.4.0.0"))
			})
		})

		Context("when download page has no valid Maven URLs", func() {
			BeforeEach(func() {
				html := `
				<html>
					<body>
						<p>No downloads available</p>
					</body>
				</html>
				`
				mockClient = newMockJRubyClient()
				mockClient.responses["https://www.jruby.org/download"] = html
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions found"))
			})
		})

		Context("when download page cannot be fetched", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching jruby download page"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific JRuby version", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				mockClient.responses["https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.0.0/jruby-dist-9.4.0.0-src.zip.sha256"] = "abc123def456"
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns the correct download URL", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.0.0/jruby-dist-9.4.0.0-src.zip"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("9.4.0.0"))
			})

			It("fetches and returns SHA256", func() {
				release, err := watcher.In("9.4.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123def456"))
			})
		})

		Context("when SHA256 has whitespace", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				mockClient.responses["https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.3.0.0/jruby-dist-9.3.0.0-src.zip.sha256"] = "  abc123\n"
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("trims whitespace from SHA256", func() {
				release, err := watcher.In("9.3.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123"))
			})
		})

		Context("when SHA256 cannot be fetched", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("9.4.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching SHA256"))
			})
		})

		Context("when SHA256 is empty", func() {
			BeforeEach(func() {
				mockClient = newMockJRubyClient()
				mockClient.responses["https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.0.0/jruby-dist-9.4.0.0-src.zip.sha256"] = "   \n  "
				watcher = watchers.NewJRubyWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("9.4.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("empty SHA256"))
			})
		})
	})
})
