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

type mockYarnBerryClient struct {
	responses map[string]string
}

func (m *mockYarnBerryClient) Get(url string) (*http.Response, error) {
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

func (m *mockYarnBerryClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockYarnBerryClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockYarnBerryClient() *mockYarnBerryClient {
	return &mockYarnBerryClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("YarnBerryWatcher", func() {
	var (
		watcher    *watchers.YarnBerryWatcher
		mockClient *mockYarnBerryClient
	)

	Describe("Check", func() {
		Context("when repo.yarnpkg.com has tags", func() {
			BeforeEach(func() {
				tags := `{
					"aliases": {"latest": "4.18.0", "stable": "4.18.0"},
					"tags": ["4.18.0", "4.17.1", "4.17.0", "3.8.7"]
				}`
				mockClient = newMockYarnBerryClient()
				mockClient.responses["https://repo.yarnpkg.com/tags"] = tags
				watcher = watchers.NewYarnBerryWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("3.8.7"))
				Expect(versions[1].Ref).To(Equal("4.17.0"))
				Expect(versions[2].Ref).To(Equal("4.17.1"))
				Expect(versions[3].Ref).To(Equal("4.18.0"))
			})
		})

		Context("when repo.yarnpkg.com is unreachable", func() {
			BeforeEach(func() {
				mockClient = newMockYarnBerryClient()
				watcher = watchers.NewYarnBerryWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching yarn berry tags"))
			})
		})

		Context("when the response body is not valid JSON", func() {
			BeforeEach(func() {
				mockClient = newMockYarnBerryClient()
				mockClient.responses["https://repo.yarnpkg.com/tags"] = "not json"
				watcher = watchers.NewYarnBerryWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("decoding JSON"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific Yarn Berry version", func() {
			BeforeEach(func() {
				binaryContent := "fake yarn berry binary content"
				mockClient = newMockYarnBerryClient()
				mockClient.responses["https://repo.yarnpkg.com/4.18.0/packages/yarnpkg-cli/bin/yarn.js"] = binaryContent
				watcher = watchers.NewYarnBerryWatcher(mockClient)
			})

			It("returns the correct download URL", func() {
				release, err := watcher.In("4.18.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://repo.yarnpkg.com/4.18.0/packages/yarnpkg-cli/bin/yarn.js"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("4.18.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("4.18.0"))
			})

			It("computes SHA256 of the binary", func() {
				release, err := watcher.In("4.18.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).NotTo(BeEmpty())
				Expect(release.SHA256).To(HaveLen(64))
			})

			It("computes the correct SHA256 hash", func() {
				release, err := watcher.In("4.18.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("022ee60deff0020b126d77c82db9e86f967fce91e3e26aa5c51557be0252a9d1"))
			})
		})

		Context("when the binary cannot be fetched", func() {
			BeforeEach(func() {
				mockClient = newMockYarnBerryClient()
				watcher = watchers.NewYarnBerryWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("4.18.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching yarn berry binary"))
			})
		})
	})
})
