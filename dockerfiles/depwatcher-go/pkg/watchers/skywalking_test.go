package watchers_test

import (
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockSkyWalkingClient struct {
	responses map[string]string
	err       error
}

func (m *mockSkyWalkingClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}

	response := m.responses[url]
	if response == "" {
		response = m.responses["default"]
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(response)),
	}, nil
}

func (m *mockSkyWalkingClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("SkyWalkingWatcher", func() {
	var (
		client  *mockSkyWalkingClient
		watcher *watchers.SkyWalkingWatcher
	)

	BeforeEach(func() {
		client = &mockSkyWalkingClient{responses: make(map[string]string)}
		watcher = watchers.NewSkyWalkingWatcher(client)
	})

	Describe("Check", func() {
		Context("when the HTML contains Java Agent version", func() {
			It("returns only the Java Agent version", func() {
				client.responses["default"] = `<html><body>
					<div class="card-body">
						<div class="title-box"><div class="card-title">Java Agent</div></div>
						<div class="dropdown-header">v8.11.0</div>
					</div>
					<div class="card-body">
						<div class="title-box"><div class="card-title">Other Component</div></div>
						<div class="dropdown-header">v8.10.0</div>
					</div>
				</body></html>`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("8.11.0"))
			})
		})
	})

	Describe("In", func() {
		Context("when mirror page contains download URL", func() {
			It("returns the mirror download URL", func() {
				client.responses["default"] = `<html><body>
					<div class="container">
						<p><a><strong>https://downloads.apache.org/skywalking/java-agent/8.11.0/apache-skywalking-java-agent-8.11.0.tgz</strong></a></p>
					</div>
				</body></html>`

				release, err := watcher.In("8.11.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.11.0"))
				Expect(release.URL).To(ContainSubstring("skywalking"))
			})
		})

		Context("when mirror page is empty", func() {
			It("falls back to archive URL", func() {
				client.responses["default"] = `<html><body></body></html>`

				release, err := watcher.In("8.11.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.11.0"))
				Expect(release.URL).To(Equal("https://archive.apache.org/dist/skywalking/java-agent/8.11.0/apache-skywalking-java-agent-8.11.0.tgz"))
			})
		})
	})
})
