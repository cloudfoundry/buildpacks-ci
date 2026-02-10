package watchers_test

import (
	"io"
	"net/http"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type tomcatMockClient struct {
	response *http.Response
	err      error
}

func (m *tomcatMockClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.response, nil
}

func (m *tomcatMockClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("TomcatWatcher", func() {
	var (
		watcher    *watchers.TomcatWatcher
		mockClient *tomcatMockClient
	)

	BeforeEach(func() {
		mockClient = &tomcatMockClient{}
	})

	Describe("Check", func() {
		Context("when the HTML directory listing is valid", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`<html>
<body>
<a href="v8.5.0/">v8.5.0/</a>
<a href="v8.5.100/">v8.5.100/</a>
<a href="v9.0.0/">v9.0.0/</a>
<a href="v9.0.82/">v9.0.82/</a>
<a href="v10.1.0/">v10.1.0/</a>
<a href="v10.1.5/">v10.1.5/</a>
</body>
</html>`)),
				}
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat/tomcat-10")
			})

			It("returns a list of versions sorted", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(6))
				Expect(versions[0].Ref).To(Equal("8.5.0"))
				Expect(versions[1].Ref).To(Equal("8.5.100"))
				Expect(versions[2].Ref).To(Equal("9.0.0"))
				Expect(versions[3].Ref).To(Equal("9.0.82"))
				Expect(versions[4].Ref).To(Equal("10.1.0"))
				Expect(versions[5].Ref).To(Equal("10.1.5"))
			})
		})

		Context("when URI is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewTomcatWatcher(mockClient, "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("uri must be specified"))
			})
		})

		Context("when the server returns an error", func() {
			BeforeEach(func() {
				mockClient.err = http.ErrHandlerTimeout
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching Tomcat directory listing"))
			})
		})

		Context("when the server returns non-200 status", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 404,
					Body:       io.NopCloser(strings.NewReader("")),
				}
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected status code 404"))
			})
		})

		Context("when the HTML has no version links", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader("<html><body>No versions here</body></html>")),
				}
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat")
			})

			It("returns an empty list", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(BeEmpty())
			})
		})
	})

	Describe("In", func() {
		Context("with valid version", func() {
			BeforeEach(func() {
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat/tomcat-10")
			})

			It("returns the correct artifact URL", func() {
				release, err := watcher.In("10.1.5")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("10.1.5"))
				Expect(release.URL).To(Equal("https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.5/bin/apache-tomcat-10.1.5.tar.gz"))
			})
		})

		Context("with trailing slash in URI", func() {
			BeforeEach(func() {
				watcher = watchers.NewTomcatWatcher(mockClient, "https://archive.apache.org/dist/tomcat/tomcat-10/")
			})

			It("handles trailing slash correctly", func() {
				release, err := watcher.In("10.1.5")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.5/bin/apache-tomcat-10.1.5.tar.gz"))
			})
		})

		Context("when URI is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewTomcatWatcher(mockClient, "")
			})

			It("returns an error", func() {
				_, err := watcher.In("10.1.5")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("uri must be specified"))
			})
		})
	})
})
