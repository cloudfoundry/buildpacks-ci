package watchers_test

import (
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockRubygemsCLIClient struct {
	htmlResponse string
}

func (m *mockRubygemsCLIClient) Get(url string) (*http.Response, error) {
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(m.htmlResponse)),
	}, nil
}

func (m *mockRubygemsCLIClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("RubygemsCLIWatcher", func() {
	var (
		watcher *watchers.RubygemsCLIWatcher
		client  *mockRubygemsCLIClient
	)

	BeforeEach(func() {
		client = &mockRubygemsCLIClient{}
		watcher = watchers.NewRubygemsCLIWatcher(client)
	})

	Context("Check", func() {
		It("extracts versions from download page", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.1.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.5.0.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("3.4.0"))
			Expect(versions[1].Ref).To(Equal("3.4.1"))
			Expect(versions[2].Ref).To(Equal("3.5.0"))
		})

		It("sorts versions by semver", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.10.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.2.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.9.0.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("3.2.0"))
			Expect(versions[1].Ref).To(Equal("3.9.0"))
			Expect(versions[2].Ref).To(Equal("3.10.0"))
		})

		It("handles multiple links with same version", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.zip">zip</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.1.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("3.4.0"))
			Expect(versions[1].Ref).To(Equal("3.4.1"))
		})

		It("only matches links with text 'tgz'", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.1.tgz">zip</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.2.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("3.4.0"))
			Expect(versions[1].Ref).To(Equal("3.4.2"))
		})

		It("returns error when no versions found", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<p>No downloads available</p>
					</div>
				</html>
			`

			_, err := watcher.Check()

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("could not parse rubygems download website"))
		})

		It("handles complex version numbers", func() {
			client.htmlResponse = `
				<html>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.rc1.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.tgz">tgz</a>
						<a href="https://rubygems.org/rubygems/rubygems-3.4.1.beta.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
		})

		It("extracts from div with id 'formats'", func() {
			client.htmlResponse = `
				<html>
					<div id="other">
						<a href="https://rubygems.org/rubygems/rubygems-1.0.0.tgz">tgz</a>
					</div>
					<div id="formats">
						<a href="https://rubygems.org/rubygems/rubygems-3.4.0.tgz">tgz</a>
					</div>
				</html>
			`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("3.4.0"))
		})
	})

	Context("In", func() {
		It("returns download URL for version", func() {
			release, err := watcher.In("3.4.10")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.4.10"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.4.10.tgz"))
		})

		It("constructs URL with version", func() {
			release, err := watcher.In("3.5.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.5.0"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.5.0.tgz"))
		})

		It("handles pre-release versions", func() {
			release, err := watcher.In("3.4.0.rc1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.4.0.rc1"))
			Expect(release.URL).To(Equal("https://rubygems.org/rubygems/rubygems-3.4.0.rc1.tgz"))
		})
	})
})
