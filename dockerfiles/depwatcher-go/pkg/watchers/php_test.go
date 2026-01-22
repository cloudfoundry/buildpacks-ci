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

type mockPHPClient struct {
	responses map[string]string
}

func (m *mockPHPClient) Get(url string) (*http.Response, error) {
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

func (m *mockPHPClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockPHPClient() *mockPHPClient {
	return &mockPHPClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("PHPWatcher", func() {
	var (
		watcher    *watchers.PHPWatcher
		mockClient *mockPHPClient
	)

	Describe("Check", func() {
		Context("when version_filter is provided and JSON API works", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.0": {
						"source": [
							{"filename": "php-8.2.0.tar.gz", "sha256": "abc123"}
						]
					},
					"8.2.1": {
						"source": [
							{"filename": "php-8.2.1.tar.gz", "sha256": "def456"}
						]
					},
					"8.2.2": {
						"source": [
							{"filename": "php-8.2.2.tar.gz", "sha256": "ghi789"}
						]
					}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("returns versions sorted by semver", func() {
				versions, err := watcher.Check("8.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("8.2.0"))
				Expect(versions[1].Ref).To(Equal("8.2.1"))
				Expect(versions[2].Ref).To(Equal("8.2.2"))
			})
		})

		Context("when JSON response contains pre-release versions", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.0": {
						"source": [{"filename": "php-8.2.0.tar.gz", "sha256": "abc123"}]
					},
					"8.2.1alpha1": {
						"source": [{"filename": "php-8.2.1alpha1.tar.gz", "sha256": "def456"}]
					},
					"8.2.2beta2": {
						"source": [{"filename": "php-8.2.2beta2.tar.gz", "sha256": "ghi789"}]
					},
					"8.2.3RC1": {
						"source": [{"filename": "php-8.2.3RC1.tar.gz", "sha256": "jkl012"}]
					},
					"8.2.4": {
						"source": [{"filename": "php-8.2.4.tar.gz", "sha256": "mno345"}]
					}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("filters out alpha, beta, and RC versions", func() {
				versions, err := watcher.Check("8.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("8.2.0"))
				Expect(versions[1].Ref).To(Equal("8.2.4"))
			})
		})

		Context("when JSON API fails and falls back to HTML", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<h2>8.2.0</h2>
							<h2>8.2.1</h2>
							<h2>8.1.15</h2>
							<h2>8.3.0</h2>
						</body>
					</html>
				`
				mockClient = newMockPHPClient()
				mockClient.responses["https://secure.php.net/releases/"] = htmlResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("returns only matching major.minor versions", func() {
				versions, err := watcher.Check("8.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("8.2.0"))
				Expect(versions[1].Ref).To(Equal("8.2.1"))
			})
		})

		Context("when version_filter is not provided", func() {
			BeforeEach(func() {
				htmlResponse := `
					<html>
						<body>
							<h2>7.4.33</h2>
							<h2>8.0.28</h2>
							<h2>8.1.15</h2>
							<h2>8.2.3</h2>
						</body>
					</html>
				`
				jsonResponse := `{
					"8.2.0": {"source": [{"filename": "php-8.2.0.tar.gz", "sha256": "abc"}]},
					"8.2.1": {"source": [{"filename": "php-8.2.1.tar.gz", "sha256": "def"}]},
					"8.2.2": {"source": [{"filename": "php-8.2.2.tar.gz", "sha256": "ghi"}]},
					"8.2.3": {"source": [{"filename": "php-8.2.3.tar.gz", "sha256": "jkl"}]}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://secure.php.net/releases/"] = htmlResponse
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("automatically detects latest major.minor version", func() {
				versions, err := watcher.Check("")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(4))
				Expect(versions[0].Ref).To(Equal("8.2.0"))
				Expect(versions[3].Ref).To(Equal("8.2.3"))
			})
		})

		Context("when version_filter is invalid", func() {
			BeforeEach(func() {
				mockClient = newMockPHPClient()
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("returns an error for single-part version", func() {
				_, err := watcher.Check("8")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version_filter must be in format 'major.minor'"))
			})
		})

		Context("when there are duplicate versions", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.0": {"source": [{"filename": "php-8.2.0.tar.gz", "sha256": "abc"}]},
					"8.2.1": {"source": [{"filename": "php-8.2.1.tar.gz", "sha256": "def"}]},
					"8.2.0": {"source": [{"filename": "php-8.2.0.tar.gz", "sha256": "abc"}]}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("deduplicates versions", func() {
				versions, err := watcher.Check("8.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
			})
		})
	})

	Describe("In", func() {
		Context("when SHA256 is available from JSON API", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.3": {
						"source": [
							{"filename": "php-8.2.3.tar.bz2", "sha256": "wronghash"},
							{"filename": "php-8.2.3.tar.gz", "sha256": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"},
							{"filename": "php-8.2.3.tar.xz", "sha256": "anotherhash"}
						]
					}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("returns release with SHA256 from JSON", func() {
				release, err := watcher.In("8.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.2.3"))
				Expect(release.URL).To(Equal("https://php.net/distributions/php-8.2.3.tar.gz"))
				Expect(release.SHA256).To(Equal("abc123def456abc123def456abc123def456abc123def456abc123def456abc1"))
			})

			It("selects the tar.gz file specifically", func() {
				release, err := watcher.In("8.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).NotTo(Equal("wronghash"))
				Expect(release.SHA256).NotTo(Equal("anotherhash"))
			})
		})

		Context("when JSON API fails and falls back to download", func() {
			BeforeEach(func() {
				mockClient = newMockPHPClient()
				mockClient.responses["https://php.net/distributions/php-8.2.3.tar.gz"] = "test-php-content"
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("computes SHA256 by downloading the file", func() {
				release, err := watcher.In("8.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.2.3"))
				Expect(release.URL).To(Equal("https://php.net/distributions/php-8.2.3.tar.gz"))
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when version is not found in JSON", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.0": {
						"source": [{"filename": "php-8.2.0.tar.gz", "sha256": "abc123"}]
					}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				mockClient.responses["https://php.net/distributions/php-8.2.3.tar.gz"] = "fallback-content"
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("falls back to computing SHA256", func() {
				release, err := watcher.In("8.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when tar.gz is not in source list", func() {
			BeforeEach(func() {
				jsonResponse := `{
					"8.2.3": {
						"source": [
							{"filename": "php-8.2.3.tar.bz2", "sha256": "wronghash"},
							{"filename": "php-8.2.3.tar.xz", "sha256": "anotherhash"}
						]
					}
				}`
				mockClient = newMockPHPClient()
				mockClient.responses["https://www.php.net/releases/index.php?json&version=8.2&max=1000"] = jsonResponse
				mockClient.responses["https://php.net/distributions/php-8.2.3.tar.gz"] = "fallback-content"
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("falls back to computing SHA256", func() {
				release, err := watcher.In("8.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(MatchRegexp(`^[a-f0-9]{64}$`))
			})
		})

		Context("when version format is invalid", func() {
			BeforeEach(func() {
				mockClient = newMockPHPClient()
				watcher = watchers.NewPHPWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("invalid")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("invalid version format"))
			})
		})
	})
})
