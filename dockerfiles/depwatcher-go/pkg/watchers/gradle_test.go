package watchers_test

import (
	"io"
	"net/http"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// gradleMockClient for testing Gradle watcher
type gradleMockClient struct {
	response *http.Response
	err      error
}

func (m *gradleMockClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.response, nil
}

func (m *gradleMockClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("GradleWatcher", func() {
	var (
		watcher    *watchers.GradleWatcher
		mockClient *gradleMockClient
	)

	BeforeEach(func() {
		mockClient = &gradleMockClient{}
		watcher = watchers.NewGradleWatcher(mockClient)
	})

	Describe("Check", func() {
		Context("when the API returns valid JSON", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`{
						"finalReleases": [
							{"version": "8.5"},
							{"version": "8.4"},
							{"version": "8.3"},
							{"version": "7.6.4"},
							{"version": "7.6.3"}
						]
					}`)),
				}
			})

			It("returns a list of versions sorted", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(5))
				Expect(versions[0].Ref).To(Equal("7.6.3"))
				Expect(versions[1].Ref).To(Equal("7.6.4"))
				Expect(versions[2].Ref).To(Equal("8.3"))
				Expect(versions[3].Ref).To(Equal("8.4"))
				Expect(versions[4].Ref).To(Equal("8.5"))
			})
		})

		Context("when the API returns an error", func() {
			BeforeEach(func() {
				mockClient.err = http.ErrHandlerTimeout
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch Gradle releases"))
			})
		})

		Context("when the API returns non-200 status", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 404,
					Body:       io.NopCloser(strings.NewReader("")),
				}
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected status code 404"))
			})
		})

		Context("when the API returns invalid JSON", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader("invalid json")),
				}
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to decode"))
			})
		})

		Context("when the API returns empty releases", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`{
						"finalReleases": []
					}`)),
				}
			})

			It("returns an empty list", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(BeEmpty())
			})
		})
	})

	Describe("In", func() {
		It("returns the correct download URL", func() {
			release, err := watcher.In("8.5")
			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("8.5"))
			Expect(release.URL).To(Equal("https://downloads.gradle.org/distributions/gradle-8.5-bin.zip"))
		})

		It("constructs URL correctly for different versions", func() {
			release, err := watcher.In("7.6.4")
			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("7.6.4"))
			Expect(release.URL).To(Equal("https://downloads.gradle.org/distributions/gradle-7.6.4-bin.zip"))
		})
	})
})
