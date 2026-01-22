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

type mockGoClient struct {
	responses map[string]string
}

func (m *mockGoClient) Get(url string) (*http.Response, error) {
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

func (m *mockGoClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockGoClient() *mockGoClient {
	return &mockGoClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("GoWatcher", func() {
	var (
		watcher    *watchers.GoWatcher
		mockClient *mockGoClient
	)

	Describe("Check", func() {
		Context("when there are multiple Go releases", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123def456abc123def456abc123def456abc123def456abc123def456abc1</tt></td>
								</tr>
								<tr>
									<td><a href="/dl/go1.20.1.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>def456abc123def456abc123def456abc123def456abc123def456abc123def4</tt></td>
								</tr>
								<tr>
									<td><a href="/dl/go1.19.5.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi7</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("1.19.5"))
				Expect(versions[1].Ref).To(Equal("1.20.0"))
				Expect(versions[2].Ref).To(Equal("1.20.1"))
			})
		})

		Context("when there are non-source rows in the table", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.linux-amd64.tar.gz">Archive</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>wronghash1</tt></td>
								</tr>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123def456abc123def456abc123def456abc123def456abc123def456abc1</tt></td>
								</tr>
								<tr>
									<td><a href="/dl/go1.20.0.darwin-amd64.tar.gz">Archive</a></td>
									<td>macOS</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>wronghash2</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("returns only source releases", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("1.20.0"))
			})
		})

		Context("when there are rows with insufficient columns", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
								</tr>
								<tr>
									<td><a href="/dl/go1.20.1.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123def456abc123def456abc123def456abc123def456abc123def456abc1</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("skips invalid rows", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("1.20.1"))
			})
		})

		Context("when there are no source releases", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.linux-amd64.tar.gz">Archive</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("returns an empty list", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(0))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123def456abc123def456abc123def456abc123def456abc123def456abc1</tt></td>
								</tr>
								<tr>
									<td><a href="/dl/go1.20.1.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>def456abc123def456abc123def456abc123def456abc123def456abc123def4</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("returns the release details", func() {
				release, err := watcher.In("1.20.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.20.0"))
				Expect(release.URL).To(Equal("https://dl.google.com/go/go1.20.0.src.tar.gz"))
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})
		})

		Context("when version is not found", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>abc123</tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("1.21.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find data for version 1.21.0"))
			})
		})

		Context("when the SHA256 field contains whitespace", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<table>
								<tr>
									<td><a href="/dl/go1.20.0.src.tar.gz">Source</a></td>
									<td>Linux</td>
									<td>x86-64</td>
									<td>123456</td>
									<td></td>
									<td><tt>  abc123def456abc123def456abc123def456abc123def456abc123def456abc1  </tt></td>
								</tr>
							</table>
						</body>
					</html>
				`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/"] = htmlResponse
				watcher = watchers.NewGoWatcher(mockClient)
			})

			It("trims whitespace from SHA256", func() {
				release, err := watcher.In("1.20.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})
		})
	})
})
