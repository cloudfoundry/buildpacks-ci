package watchers_test

import (
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockZuluClient struct {
	response string
	err      error
}

func (m *mockZuluClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(m.response)),
	}, nil
}

func (m *mockZuluClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("ZuluWatcher", func() {
	var (
		client  *mockZuluClient
		watcher *watchers.ZuluWatcher
	)

	BeforeEach(func() {
		client = &mockZuluClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid release data", func() {
			It("returns the version", func() {
				client.response = `{
					"jdk_version": [8, 0, 302],
					"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
				}`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("8.0.302"))
			})
		})

		Context("when version is missing", func() {
			It("returns an error", func() {
				watcher = watchers.NewZuluWatcher(client, "", "jdk")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version must be specified"))
			})
		})

		Context("when type is missing", func() {
			It("returns an error", func() {
				watcher = watchers.NewZuluWatcher(client, "8", "")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("type must be specified"))
			})
		})

		Context("when version has invalid number of components", func() {
			It("returns an error", func() {
				client.response = `{
					"jdk_version": [8, 0],
					"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
				}`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version must have three components"))
			})
		})
	})

	Describe("In", func() {
		Context("when version matches", func() {
			It("returns the release details", func() {
				client.response = `{
					"jdk_version": [8, 0, 302],
					"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
				}`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				release, err := watcher.In("8.0.302")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.0.302"))
				Expect(release.URL).To(Equal("https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"))
			})
		})

		Context("when version does not match", func() {
			It("returns an error", func() {
				client.response = `{
					"jdk_version": [8, 0, 302],
					"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
				}`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				_, err := watcher.In("8.0.999")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version mismatch"))
			})
		})
	})
})
