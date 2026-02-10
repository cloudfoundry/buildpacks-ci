package watchers_test

import (
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockWildflyClient struct {
	response string
	err      error
}

func (m *mockWildflyClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(m.response)),
	}, nil
}

func (m *mockWildflyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("WildflyWatcher", func() {
	var (
		client  *mockWildflyClient
		watcher *watchers.WildflyWatcher
	)

	BeforeEach(func() {
		client = &mockWildflyClient{}
		watcher = watchers.NewWildflyWatcher(client)
	})

	Describe("Check", func() {
		Context("when the HTML contains version IDs", func() {
			It("returns sorted versions", func() {
				client.response = `<html><body>
					<div class="version-id">26.1.0.Final</div>
					<div class="version-id">26.0.1.Final</div>
					<div class="version-id">25.0.0.Final</div>
				</body></html>`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("25.0.0-Final"))
				Expect(versions[1].Ref).To(Equal("26.0.1-Final"))
				Expect(versions[2].Ref).To(Equal("26.1.0-Final"))
			})
		})
	})

	Describe("In", func() {
		Context("when version is valid", func() {
			It("returns the release details", func() {
				release, err := watcher.In("26.1.0-Final")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("26.1.0-Final"))
				Expect(release.URL).To(Equal("https://download.jboss.org/wildfly/26.1.0.Final/wildfly-26.1.0.Final.tar.gz"))
			})
		})

		Context("when version is invalid", func() {
			It("returns an error", func() {
				_, err := watcher.In("invalid")
				Expect(err).To(HaveOccurred())
			})
		})
	})
})
