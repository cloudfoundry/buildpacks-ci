package watchers_test

import (
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockJProfilerClient struct {
	response string
	err      error
}

func (m *mockJProfilerClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(m.response)),
	}, nil
}

func (m *mockJProfilerClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("JProfilerWatcher", func() {
	var (
		client  *mockJProfilerClient
		watcher *watchers.JProfilerWatcher
	)

	BeforeEach(func() {
		client = &mockJProfilerClient{}
		watcher = watchers.NewJProfilerWatcher(client)
	})

	Describe("Check", func() {
		Context("when the HTML contains release headings", func() {
			It("returns sorted versions", func() {
				client.response = `<html><body>
					<div class="release-heading">Release 13.0.3 (Build 13033)</div>
					<div class="release-heading">Release 13.0.2 (Build 13024)</div>
					<div class="release-heading">Release 12.0.4 (Build 12048)</div>
				</body></html>`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("12.0.4"))
				Expect(versions[1].Ref).To(Equal("13.0.2"))
				Expect(versions[2].Ref).To(Equal("13.0.3"))
			})
		})
	})

	Describe("In", func() {
		Context("when version has a patch number", func() {
			It("returns the release details with patch in filename", func() {
				release, err := watcher.In("13.0.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("13.0.3"))
				Expect(release.URL).To(Equal("https://download-gcdn.ej-technologies.com/jprofiler/jprofiler_linux_13_0_3.tar.gz"))
			})
		})

		Context("when version has no patch number", func() {
			It("returns the release details without patch in filename", func() {
				release, err := watcher.In("13.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("13.0.0"))
				Expect(release.URL).To(Equal("https://download-gcdn.ej-technologies.com/jprofiler/jprofiler_linux_13_0.tar.gz"))
			})
		})
	})
})
