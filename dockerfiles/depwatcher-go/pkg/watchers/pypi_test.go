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

type mockPyPIClient struct {
	responses map[string]string
}

func (m *mockPyPIClient) Get(url string) (*http.Response, error) {
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

func (m *mockPyPIClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockPyPIClient() *mockPyPIClient {
	return &mockPyPIClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("PyPIWatcher", func() {
	var (
		watcher    *watchers.PyPIWatcher
		mockClient *mockPyPIClient
	)

	Describe("Check", func() {
		Context("when PyPI has multiple versions", func() {
			BeforeEach(func() {
				pypiJSON := `{
					"releases": {
						"1.0.0": [],
						"1.1.0": [],
						"1.2.0": [],
						"2.0.0": [],
						"2.1.0": [],
						"2.2.0": [],
						"3.0.0": [],
						"3.1.0": [],
						"3.2.0": [],
						"3.3.0": [],
						"3.4.0": [],
						"3.5.0": [],
						"3.6.0rc1": [],
						"3.6.0": []
					}
				}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/somepackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns only final releases sorted by semver", func() {
				versions, err := watcher.Check("somepackage")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions[0].Ref).To(Equal("2.0.0"))
				Expect(versions[len(versions)-1].Ref).To(Equal("3.6.0"))
			})

			It("returns at most 10 versions", func() {
				versions, err := watcher.Check("somepackage")
				Expect(err).NotTo(HaveOccurred())
				Expect(len(versions)).To(Equal(10))
			})

			It("excludes pre-release versions", func() {
				versions, err := watcher.Check("somepackage")
				Expect(err).NotTo(HaveOccurred())
				for _, v := range versions {
					Expect(v.Ref).NotTo(ContainSubstring("rc"))
					Expect(v.Ref).NotTo(ContainSubstring("alpha"))
					Expect(v.Ref).NotTo(ContainSubstring("beta"))
				}
			})
		})

		Context("when PyPI has fewer than 10 versions", func() {
			BeforeEach(func() {
				pypiJSON := `{
					"releases": {
						"1.0.0": [],
						"1.1.0": [],
						"1.2.0": []
					}
				}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/smallpackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns all available versions", func() {
				versions, err := watcher.Check("smallpackage")
				Expect(err).NotTo(HaveOccurred())
				Expect(len(versions)).To(Equal(3))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("1.1.0"))
				Expect(versions[2].Ref).To(Equal("1.2.0"))
			})
		})

		Context("when package does not exist", func() {
			BeforeEach(func() {
				mockClient = newMockPyPIClient()
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check("nonexistent")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching pypi package"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version with sdist", func() {
			BeforeEach(func() {
				pypiJSON := `{
					"releases": {
						"1.2.3": [
							{
								"url": "https://files.pythonhosted.org/packages/somepackage-1.2.3-py3-none-any.whl",
								"packagetype": "bdist_wheel",
								"md5_digest": "abc123",
								"digests": {"sha256": "def456"},
								"size": 5000
							},
							{
								"url": "https://files.pythonhosted.org/packages/somepackage-1.2.3.tar.gz",
								"packagetype": "sdist",
								"md5_digest": "xyz789",
								"digests": {"sha256": "sha256hash"},
								"size": 10000
							}
						]
					}
				}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/somepackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns the sdist download URL", func() {
				release, err := watcher.In("somepackage", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://files.pythonhosted.org/packages/somepackage-1.2.3.tar.gz"))
			})

			It("returns the version ref", func() {
				release, err := watcher.In("somepackage", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
			})

			It("returns MD5 and SHA256 digests", func() {
				release, err := watcher.In("somepackage", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.MD5).To(Equal("xyz789"))
				Expect(release.SHA256).To(Equal("sha256hash"))
			})

			It("selects sdist over wheel", func() {
				release, err := watcher.In("somepackage", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(ContainSubstring(".tar.gz"))
				Expect(release.URL).NotTo(ContainSubstring(".whl"))
			})
		})

		Context("when multiple sdists exist", func() {
			BeforeEach(func() {
				pypiJSON := `{
					"releases": {
						"1.2.3": [
							{
								"url": "https://files.pythonhosted.org/packages/somepackage-1.2.3.tar.gz",
								"packagetype": "sdist",
								"md5_digest": "larger",
								"digests": {"sha256": "hash1"},
								"size": 20000
							},
							{
								"url": "https://files.pythonhosted.org/packages/somepackage-1.2.3-slim.tar.gz",
								"packagetype": "sdist",
								"md5_digest": "smaller",
								"digests": {"sha256": "hash2"},
								"size": 5000
							}
						]
					}
				}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/somepackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns the smallest sdist", func() {
				release, err := watcher.In("somepackage", "1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(ContainSubstring("slim"))
				Expect(release.MD5).To(Equal("smaller"))
			})
		})

		Context("when version does not exist", func() {
			BeforeEach(func() {
				pypiJSON := `{"releases": {"1.0.0": []}}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/somepackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("somepackage", "9.9.9")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version 9.9.9 not found"))
			})
		})

		Context("when no sdist is available", func() {
			BeforeEach(func() {
				pypiJSON := `{
					"releases": {
						"1.2.3": [
							{
								"url": "https://files.pythonhosted.org/packages/somepackage-1.2.3-py3-none-any.whl",
								"packagetype": "bdist_wheel",
								"md5_digest": "abc123",
								"digests": {"sha256": "def456"},
								"size": 5000
							}
						]
					}
				}`
				mockClient = newMockPyPIClient()
				mockClient.responses["https://pypi.org/pypi/somepackage/json"] = pypiJSON
				watcher = watchers.NewPyPIWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("somepackage", "1.2.3")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no sdist found"))
			})
		})
	})
})
