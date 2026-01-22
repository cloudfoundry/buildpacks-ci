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

type mockRubygemsClient struct {
	versionsResponse string
	versionResponse  map[string]string
}

func (m *mockRubygemsClient) Get(url string) (*http.Response, error) {
	if strings.Contains(url, "/api/v1/versions/") {
		return &http.Response{
			StatusCode: 200,
			Body:       io.NopCloser(strings.NewReader(m.versionsResponse)),
		}, nil
	}
	if strings.Contains(url, "/api/v2/rubygems/") {
		for version, response := range m.versionResponse {
			if strings.Contains(url, version) {
				return &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader(response)),
				}, nil
			}
		}
		return nil, fmt.Errorf("version not found")
	}
	return nil, fmt.Errorf("unexpected URL: %s", url)
}

func (m *mockRubygemsClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("RubygemsWatcher", func() {
	var (
		watcher *watchers.RubygemsWatcher
		client  *mockRubygemsClient
	)

	BeforeEach(func() {
		client = &mockRubygemsClient{
			versionResponse: make(map[string]string),
		}
	})

	Context("Check", func() {
		It("returns last 10 versions (oldest to newest)", func() {
			client.versionsResponse = `[
				{"number":"1.0.0","prerelease":false},
				{"number":"1.0.1","prerelease":false},
				{"number":"1.0.2","prerelease":false},
				{"number":"1.1.0","prerelease":false},
				{"number":"1.1.1","prerelease":false},
				{"number":"1.2.0","prerelease":false},
				{"number":"1.2.1","prerelease":false},
				{"number":"1.2.2","prerelease":false},
				{"number":"1.3.0","prerelease":false},
				{"number":"1.3.1","prerelease":false},
				{"number":"1.4.0","prerelease":false},
				{"number":"2.0.0","prerelease":false}
			]`

			watcher = watchers.NewRubygemsWatcher(client, "rake")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(10))
			Expect(releases[0].Ref).To(Equal("1.0.2"))
			Expect(releases[1].Ref).To(Equal("1.1.0"))
			Expect(releases[2].Ref).To(Equal("1.1.1"))
			Expect(releases[9].Ref).To(Equal("2.0.0"))
		})

		It("filters out prerelease versions", func() {
			client.versionsResponse = `[
				{"number":"1.0.0","prerelease":false},
				{"number":"1.1.0.beta","prerelease":true},
				{"number":"1.1.0.rc1","prerelease":true},
				{"number":"1.1.0","prerelease":false},
				{"number":"2.0.0.alpha","prerelease":true},
				{"number":"2.0.0","prerelease":false}
			]`

			watcher = watchers.NewRubygemsWatcher(client, "rails")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(3))
			Expect(releases[0].Ref).To(Equal("1.0.0"))
			Expect(releases[1].Ref).To(Equal("1.1.0"))
			Expect(releases[2].Ref).To(Equal("2.0.0"))
		})

		It("sorts versions by semver", func() {
			client.versionsResponse = `[
				{"number":"1.10.0","prerelease":false},
				{"number":"1.2.0","prerelease":false},
				{"number":"1.9.0","prerelease":false},
				{"number":"2.0.0","prerelease":false},
				{"number":"1.11.0","prerelease":false}
			]`

			watcher = watchers.NewRubygemsWatcher(client, "gem")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(5))
			Expect(releases[0].Ref).To(Equal("1.2.0"))
			Expect(releases[1].Ref).To(Equal("1.9.0"))
			Expect(releases[2].Ref).To(Equal("1.10.0"))
			Expect(releases[3].Ref).To(Equal("1.11.0"))
			Expect(releases[4].Ref).To(Equal("2.0.0"))
		})

		It("returns only stable versions when all releases are stable", func() {
			client.versionsResponse = `[
				{"number":"3.0.0","prerelease":false},
				{"number":"3.1.0","prerelease":false},
				{"number":"3.2.0","prerelease":false}
			]`

			watcher = watchers.NewRubygemsWatcher(client, "bundler")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(3))
			Expect(releases[0].Ref).To(Equal("3.0.0"))
			Expect(releases[1].Ref).To(Equal("3.1.0"))
			Expect(releases[2].Ref).To(Equal("3.2.0"))
		})

		It("handles empty version list", func() {
			client.versionsResponse = `[]`

			watcher = watchers.NewRubygemsWatcher(client, "nonexistent")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(0))
		})

		It("returns fewer than 10 versions if available count is less", func() {
			client.versionsResponse = `[
				{"number":"1.0.0","prerelease":false},
				{"number":"1.1.0","prerelease":false},
				{"number":"1.2.0","prerelease":false}
			]`

			watcher = watchers.NewRubygemsWatcher(client, "smallgem")
			releases, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(releases).To(HaveLen(3))
		})
	})

	Context("In", func() {
		It("returns release details with SHA256", func() {
			client.versionResponse["2.5.0"] = `{
				"number": "2.5.0",
				"sha": "abc123def456",
				"prerelease": false,
				"source_code_uri": "https://github.com/rake/rake/tree/v2.5.0"
			}`

			watcher = watchers.NewRubygemsWatcher(client, "rake")
			release, err := watcher.In("2.5.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("2.5.0"))
			Expect(release.SHA256).To(Equal("abc123def456"))
			Expect(release.URL).To(Equal("https://github.com/rake/rake/tree/v2.5.0"))
		})

		It("uses source_code_uri as-is", func() {
			client.versionResponse["7.0.0"] = `{
				"number": "7.0.0",
				"sha": "sha256hash",
				"prerelease": false,
				"source_code_uri": "https://github.com/rails/rails/tree/v7.0.0"
			}`

			watcher = watchers.NewRubygemsWatcher(client, "rails")
			release, err := watcher.In("7.0.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("7.0.0"))
			Expect(release.URL).To(Equal("https://github.com/rails/rails/tree/v7.0.0"))
		})

		It("handles different gem names", func() {
			client.versionResponse["3.2.1"] = `{
				"number": "3.2.1",
				"sha": "fedcba654321",
				"prerelease": false,
				"source_code_uri": "https://github.com/bundler/bundler/tree/v3.2.1"
			}`

			watcher = watchers.NewRubygemsWatcher(client, "bundler")
			release, err := watcher.In("3.2.1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("3.2.1"))
			Expect(release.SHA256).To(Equal("fedcba654321"))
		})

		It("returns error when version not found", func() {
			watcher = watchers.NewRubygemsWatcher(client, "rake")
			_, err := watcher.In("99.99.99")

			Expect(err).To(HaveOccurred())
		})
	})

	Context("API Integration", func() {
		It("uses correct v1 API endpoint for Check", func() {
			client.versionsResponse = `[{"number":"1.0.0","prerelease":false}]`
			watcher = watchers.NewRubygemsWatcher(client, "test-gem")

			_, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
		})

		It("uses correct v2 API endpoint for In", func() {
			client.versionResponse["1.0.0"] = `{
				"number": "1.0.0",
				"sha": "abc",
				"prerelease": false,
				"source_code_uri": "https://github.com/test/test"
			}`
			watcher = watchers.NewRubygemsWatcher(client, "test-gem")

			_, err := watcher.In("1.0.0")

			Expect(err).NotTo(HaveOccurred())
		})
	})
})
