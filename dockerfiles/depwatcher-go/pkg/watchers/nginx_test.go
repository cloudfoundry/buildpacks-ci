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

type mockNginxClient struct {
	responses map[string]string
}

func (m *mockNginxClient) Get(url string) (*http.Response, error) {
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

func (m *mockNginxClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockNginxClient() *mockNginxClient {
	return &mockNginxClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("NginxWatcher", func() {
	var (
		watcher    *watchers.NginxWatcher
		mockClient *mockNginxClient
	)

	Describe("Check", func() {
		Context("when GitHub has release tags", func() {
			BeforeEach(func() {
				tags := `[
					{"name": "release-1.24.0", "commit": {"sha": "abc123"}},
					{"name": "release-1.25.0", "commit": {"sha": "def456"}},
					{"name": "release-1.25.1", "commit": {"sha": "ghi789"}},
					{"name": "release-1.26.0", "commit": {"sha": "jkl012"}},
					{"name": "some-other-tag", "commit": {"sha": "xyz999"}}
				]`
				mockClient = newMockNginxClient()
				mockClient.responses["https://api.github.com/repos/nginx/nginx/tags?per_page=1000"] = tags
				watcher = watchers.NewNginxWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("1.24.0"))
				Expect(versions[1].Ref).To(Equal("1.25.0"))
				Expect(versions[2].Ref).To(Equal("1.25.1"))
				Expect(versions[3].Ref).To(Equal("1.26.0"))
			})

			It("strips release- prefix from tags", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(HavePrefix("release-"))
					Expect(v.Ref).To(MatchRegexp(`^\d+\.\d+\.\d+$`))
				}
			})

			It("filters out non-release tags", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(Equal("some-other-tag"))
				}
			})
		})

		Context("when GitHub API fails", func() {
			BeforeEach(func() {
				mockClient = newMockNginxClient()
				watcher = watchers.NewNginxWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching nginx tags"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific Nginx version", func() {
			BeforeEach(func() {
				tarballContent := "fake nginx tarball content"
				mockClient = newMockNginxClient()
				mockClient.responses["http://nginx.org/download/nginx-1.25.0.tar.gz"] = tarballContent
				watcher = watchers.NewNginxWatcher(mockClient)
			})

			It("returns the correct download URL", func() {
				release, err := watcher.In("1.25.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("http://nginx.org/download/nginx-1.25.0.tar.gz"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("1.25.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.25.0"))
			})

			It("returns PGP signature URL", func() {
				release, err := watcher.In("1.25.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.PGP).To(Equal("http://nginx.org/download/nginx-1.25.0.tar.gz.asc"))
			})

			It("computes SHA256 of tarball", func() {
				release, err := watcher.In("1.25.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).NotTo(BeEmpty())
				Expect(release.SHA256).To(HaveLen(64))
			})

			It("computes correct SHA256 hash", func() {
				release, err := watcher.In("1.25.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("8db1ed918065007becdf2c40e0cb28630d4da4c7ef4c5494f083f30a6eee6d44"))
			})
		})

		Context("when tarball cannot be fetched", func() {
			BeforeEach(func() {
				mockClient = newMockNginxClient()
				watcher = watchers.NewNginxWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("1.25.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching nginx tarball"))
			})
		})
	})
})
