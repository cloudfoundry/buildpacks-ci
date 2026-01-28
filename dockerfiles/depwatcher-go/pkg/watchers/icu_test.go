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

var _ = Describe("ICUWatcher", func() {
	var (
		watcher    *watchers.ICUWatcher
		mockClient *mockICUClient
	)

	BeforeEach(func() {
		mockClient = &mockICUClient{
			responses:   make(map[string]string),
			statusCodes: make(map[string]int),
			callCount:   make(map[string]int),
		}
		watcher = watchers.NewICUWatcher(mockClient)
	})

	Describe("Check", func() {
		Context("when there are multiple releases", func() {
			It("returns sorted versions as valid semvers", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `[
					{
						"tag_name": "release-65-1",
						"draft": false,
						"prerelease": false
					},
					{
						"tag_name": "release-64-2",
						"draft": false,
						"prerelease": false
					},
					{
						"tag_name": "release-4-8-2",
						"draft": false,
						"prerelease": false
					}
				]`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("4.8.2"))
				Expect(versions[1].Ref).To(Equal("64.2.0"))
				Expect(versions[2].Ref).To(Equal("65.1.0"))
			})
		})

		Context("when there are draft releases", func() {
			It("excludes draft releases", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `[
					{
						"tag_name": "release-65-1",
						"draft": false,
						"prerelease": false
					},
					{
						"tag_name": "release-64-2",
						"draft": true,
						"prerelease": false
					}
				]`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("65.1.0"))
			})
		})

		Context("when there are prerelease versions", func() {
			It("excludes prerelease versions", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `[
					{
						"tag_name": "release-65-1",
						"draft": false,
						"prerelease": false
					},
					{
						"tag_name": "release-66-rc",
						"draft": false,
						"prerelease": true
					}
				]`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("65.1.0"))
			})
		})

		Context("when version has 2 parts", func() {
			It("appends .0 to make it 3-part semver", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `[
					{
						"tag_name": "release-65-1",
						"draft": false,
						"prerelease": false
					}
				]`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("65.1.0"))
			})
		})

		Context("when version has 3 parts", func() {
			It("does not append .0", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `[
					{
						"tag_name": "release-4-8-2",
						"draft": false,
						"prerelease": false
					}
				]`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("4.8.2"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the last 10 versions", func() {
				releases := `[`
				for i := 1; i <= 15; i++ {
					if i > 1 {
						releases += ","
					}
					releases += `{
						"tag_name": "release-` + string(rune(60+i)) + `-1",
						"draft": false,
						"prerelease": false
					}`
				}
				releases += `]`
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = releases

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
			})
		})

		Context("when the API request fails", func() {
			It("returns an error", func() {
				mockClient.statusCodes["https://api.github.com/repos/unicode-org/icu/releases"] = 500

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch ICU releases"))
			})
		})

		Context("when the response is not valid JSON", func() {
			It("returns an error", func() {
				mockClient.responses["https://api.github.com/repos/unicode-org/icu/releases"] = `invalid json`

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to decode ICU releases"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("returns release metadata with SHA256", func() {
				url := "https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz"
				mockClient.responses[url] = "dummy data"

				release, err := watcher.In("65.1.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("65.1.0"))
				Expect(release.URL).To(Equal(url))
				Expect(release.SHA256).To(Equal("797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"))
			})
		})

		Context("when version has 3 parts", func() {
			It("constructs correct URL without trailing -0", func() {
				url := "https://github.com/unicode-org/icu/releases/download/release-4-8-2/icu4c-4_8_2-src.tgz"
				mockClient.responses[url] = "dummy data"

				release, err := watcher.In("4.8.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal(url))
			})
		})

		Context("when download fails", func() {
			It("returns an error", func() {
				url := "https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz"
				mockClient.statusCodes[url] = 404

				_, err := watcher.In("65.1.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download ICU tarball"))
			})
		})
	})
})

type mockICUClient struct {
	responses   map[string]string
	statusCodes map[string]int
	callCount   map[string]int
}

func (m *mockICUClient) Get(url string) (*http.Response, error) {
	m.callCount[url]++

	statusCode, ok := m.statusCodes[url]
	if !ok {
		statusCode = 200
	}

	if statusCode != 200 {
		return nil, &http.ProtocolError{ErrorString: fmt.Sprintf("HTTP %d", statusCode)}
	}

	body, ok := m.responses[url]
	if !ok {
		body = ""
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(body)),
	}, nil
}

func (m *mockICUClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}
