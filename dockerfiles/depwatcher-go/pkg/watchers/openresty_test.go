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

type mockOpenrestyClient struct {
	tagsResponse    string
	tarballResponse string
}

func (m *mockOpenrestyClient) Get(url string) (*http.Response, error) {
	if strings.Contains(url, "api.github.com/repos/openresty/openresty/tags") {
		return &http.Response{
			StatusCode: 200,
			Body:       io.NopCloser(strings.NewReader(m.tagsResponse)),
		}, nil
	}
	if strings.Contains(url, "openresty.org/download") {
		return &http.Response{
			StatusCode: 200,
			Body:       io.NopCloser(strings.NewReader(m.tarballResponse)),
		}, nil
	}
	return nil, fmt.Errorf("unexpected URL: %s", url)
}

func (m *mockOpenrestyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("OpenrestyWatcher", func() {
	var (
		watcher *watchers.OpenrestyWatcher
		client  *mockOpenrestyClient
	)

	BeforeEach(func() {
		client = &mockOpenrestyClient{
			tarballResponse: "fake tarball content",
		}
		watcher = watchers.NewOpenrestyWatcher(client)
	})

	Context("Check", func() {
		It("extracts 4-part version numbers from GitHub tags", func() {
			client.tagsResponse = `[
				{"name": "v1.19.3.1"},
				{"name": "v1.19.3.2"},
				{"name": "v1.19.9.1"}
			]`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("1.19.3.1"))
			Expect(versions[1].Ref).To(Equal("1.19.3.2"))
			Expect(versions[2].Ref).To(Equal("1.19.9.1"))
		})

		It("strips 'v' prefix from tags", func() {
			client.tagsResponse = `[
				{"name": "v1.21.4.1"},
				{"name": "v1.21.4.2"}
			]`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("1.21.4.1"))
			Expect(versions[1].Ref).To(Equal("1.21.4.2"))
		})

		It("sorts versions by semver", func() {
			client.tagsResponse = `[
				{"name": "v1.19.9.1"},
				{"name": "v1.19.3.2"},
				{"name": "v1.21.4.1"}
			]`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(3))
			Expect(versions[0].Ref).To(Equal("1.19.3.2"))
			Expect(versions[1].Ref).To(Equal("1.19.9.1"))
			Expect(versions[2].Ref).To(Equal("1.21.4.1"))
		})

		It("only matches 4-part version numbers", func() {
			client.tagsResponse = `[
				{"name": "v1.19.3"},
				{"name": "v1.19.3.1"},
				{"name": "v1.19.3.2.1"}
			]`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("1.19.3.1"))
		})

		It("handles tags without 'v' prefix", func() {
			client.tagsResponse = `[
				{"name": "1.19.3.1"},
				{"name": "1.19.3.2"}
			]`

			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
		})
	})

	Context("In", func() {
		It("returns download URL with version", func() {
			release, err := watcher.In("1.19.3.1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("1.19.3.1"))
			Expect(release.URL).To(Equal("http://openresty.org/download/openresty-1.19.3.1.tar.gz"))
		})

		It("returns PGP signature URL", func() {
			release, err := watcher.In("1.19.3.1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.PGP).To(Equal("http://openresty.org/download/openresty-1.19.3.1.tar.gz.asc"))
		})

		It("computes SHA256 by downloading tarball", func() {
			client.tarballResponse = "fake tarball content"
			release, err := watcher.In("1.19.3.1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.SHA256).To(Equal("cd7e079c10099229b6aa1fbbdbf104dd9e8dbad195607b136eb6448ca61a62e9"))
		})

		It("handles different version numbers", func() {
			release, err := watcher.In("1.21.4.1")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("1.21.4.1"))
			Expect(release.URL).To(Equal("http://openresty.org/download/openresty-1.21.4.1.tar.gz"))
		})
	})
})
