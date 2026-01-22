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
				jsonResponse := `[
					{
						"version": "go1.20.1",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.1.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.1",
								"sha256": "def456abc123def456abc123def456abc123def456abc123def456abc123def4",
								"size": 123456,
								"kind": "source"
							}
						]
					},
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.0",
								"sha256": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
								"size": 123456,
								"kind": "source"
							}
						]
					},
					{
						"version": "go1.19.5",
						"stable": true,
						"files": [
							{
								"filename": "go1.19.5.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.19.5",
								"sha256": "ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi789abc123ghi7",
								"size": 123456,
								"kind": "source"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.linux-amd64.tar.gz",
								"os": "linux",
								"arch": "amd64",
								"version": "go1.20.0",
								"sha256": "wronghash1",
								"size": 123456,
								"kind": "archive"
							},
							{
								"filename": "go1.20.0.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.0",
								"sha256": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
								"size": 123456,
								"kind": "source"
							},
							{
								"filename": "go1.20.0.darwin-amd64.tar.gz",
								"os": "darwin",
								"arch": "amd64",
								"version": "go1.20.0",
								"sha256": "wronghash2",
								"size": 123456,
								"kind": "archive"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": []
					},
					{
						"version": "go1.20.1",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.1.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.1",
								"sha256": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
								"size": 123456,
								"kind": "source"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.linux-amd64.tar.gz",
								"os": "linux",
								"arch": "amd64",
								"version": "go1.20.0",
								"sha256": "abc123",
								"size": 123456,
								"kind": "archive"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.0",
								"sha256": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
								"size": 123456,
								"kind": "source"
							}
						]
					},
					{
						"version": "go1.20.1",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.1.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.1",
								"sha256": "def456abc123def456abc123def456abc123def456abc123def456abc123def4",
								"size": 123456,
								"kind": "source"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.0",
								"sha256": "abc123",
								"size": 123456,
								"kind": "source"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
				jsonResponse := `[
					{
						"version": "go1.20.0",
						"stable": true,
						"files": [
							{
								"filename": "go1.20.0.src.tar.gz",
								"os": "",
								"arch": "",
								"version": "go1.20.0",
								"sha256": "  abc123def456abc123def456abc123def456abc123def456abc123def456abc1  ",
								"size": 123456,
								"kind": "source"
							}
						]
					}
				]`
				mockClient = newMockGoClient()
				mockClient.responses["https://go.dev/dl/?mode=json&include=all"] = jsonResponse
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
