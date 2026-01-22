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

type mockNodeClient struct {
	responses map[string]string
}

func (m *mockNodeClient) Get(url string) (*http.Response, error) {
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

func (m *mockNodeClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func newMockNodeClient() *mockNodeClient {
	return &mockNodeClient{
		responses: make(map[string]string),
	}
}

var _ = Describe("NodeWatcher", func() {
	var (
		watcher    *watchers.NodeWatcher
		mockClient *mockNodeClient
	)

	BeforeEach(func() {
		mockClient = newMockNodeClient()
	})

	Describe("Check", func() {
		Context("when there are multiple Node.js releases", func() {
			BeforeEach(func() {
				indexJSON := `[
					{"version": "v20.0.0", "date": "2023-04-18", "files": [], "lts": false, "security": false},
					{"version": "v19.0.0", "date": "2022-10-18", "files": [], "lts": false, "security": false},
					{"version": "v18.16.0", "date": "2023-04-12", "files": [], "lts": "Hydrogen", "security": false},
					{"version": "v18.0.0", "date": "2022-04-19", "files": [], "lts": false, "security": false},
					{"version": "v17.0.0", "date": "2021-10-19", "files": [], "lts": false, "security": false},
					{"version": "v16.20.0", "date": "2023-03-28", "files": [], "lts": "Gallium", "security": false},
					{"version": "v16.0.0", "date": "2021-04-20", "files": [], "lts": false, "security": false},
					{"version": "v14.21.3", "date": "2023-02-16", "files": [], "lts": "Fermium", "security": false},
					{"version": "v12.22.12", "date": "2022-04-05", "files": [], "lts": "Erbium", "security": false},
					{"version": "v11.0.0", "date": "2018-10-23", "files": [], "lts": false, "security": false},
					{"version": "v10.24.1", "date": "2021-04-06", "files": [], "lts": false, "security": false}
				]`
				mockClient.responses["https://nodejs.org/dist/index.json"] = indexJSON
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("filters to only even major versions >= 12", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				refs := make([]string, len(versions))
				for i, v := range versions {
					refs[i] = v.Ref
				}

				Expect(refs).To(ContainElement("12.22.12"))
				Expect(refs).To(ContainElement("14.21.3"))
				Expect(refs).To(ContainElement("16.0.0"))
				Expect(refs).To(ContainElement("16.20.0"))
				Expect(refs).To(ContainElement("18.0.0"))
				Expect(refs).To(ContainElement("18.16.0"))
				Expect(refs).To(ContainElement("20.0.0"))

				Expect(refs).NotTo(ContainElement("10.24.1"))
				Expect(refs).NotTo(ContainElement("11.0.0"))
				Expect(refs).NotTo(ContainElement("17.0.0"))
				Expect(refs).NotTo(ContainElement("19.0.0"))
			})

			It("strips 'v' prefix from versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				for _, v := range versions {
					Expect(v.Ref).NotTo(HavePrefix("v"))
				}
			})

			It("sorts versions by semver", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				Expect(len(versions)).To(BeNumerically(">", 0))

				for i := 0; i < len(versions)-1; i++ {
					current := versions[i].Ref
					next := versions[i+1].Ref
					Expect(current <= next).To(BeTrue(), "Expected %s <= %s", current, next)
				}
			})
		})

		Context("when the API returns an error", func() {
			BeforeEach(func() {
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching node releases"))
			})
		})

		Context("when the API returns invalid JSON", func() {
			BeforeEach(func() {
				mockClient.responses["https://nodejs.org/dist/index.json"] = "invalid json"
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("decoding node releases"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			BeforeEach(func() {
				shasums := `d513c3f23f795ebb6e90adc51c6e1c0ed66d59d862b2efe6f29257a03c853b04  node-v18.16.0-aix-ppc64.tar.gz
0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  node-v18.16.0.tar.gz
abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789  node-v18.16.0-linux-x64.tar.gz`
				mockClient.responses["https://nodejs.org/dist/v18.16.0/SHASUMS256.txt"] = shasums
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("returns the release details with correct URL", func() {
				release, err := watcher.In("18.16.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("18.16.0"))
				Expect(release.URL).To(Equal("https://nodejs.org/dist/v18.16.0/node-v18.16.0.tar.gz"))
			})

			It("extracts the SHA256 from SHASUMS256.txt", func() {
				release, err := watcher.In("18.16.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))
			})
		})

		Context("when the SHASUMS256.txt file is not found", func() {
			BeforeEach(func() {
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("99.99.99")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching SHASUMS256.txt"))
			})
		})

		Context("when the SHA256 for the tar.gz is not found", func() {
			BeforeEach(func() {
				shasums := `d513c3f23f795ebb6e90adc51c6e1c0ed66d59d862b2efe6f29257a03c853b04  node-v18.16.0-aix-ppc64.tar.gz
abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789  node-v18.16.0-linux-x64.tar.gz`
				mockClient.responses["https://nodejs.org/dist/v18.16.0/SHASUMS256.txt"] = shasums
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("returns an error", func() {
				_, err := watcher.In("18.16.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find SHA256"))
			})
		})

		Context("when parsing various SHASUMS256.txt formats", func() {
			BeforeEach(func() {
				shasums := `abc123  node-v16.0.0.tar.gz
def456   node-v16.0.0-linux-x64.tar.gz
  ghi789     node-v16.0.0-darwin-x64.tar.gz  
`
				mockClient.responses["https://nodejs.org/dist/v16.0.0/SHASUMS256.txt"] = shasums
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("handles various whitespace formats", func() {
				release, err := watcher.In("16.0.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.SHA256).To(Equal("abc123"))
			})
		})
	})

	Describe("LTS Filtering Logic", func() {
		Context("when checking Node.js LTS releases", func() {
			BeforeEach(func() {
				indexJSON := `[
					{"version": "v22.0.0", "date": "2024-04-24", "files": [], "lts": false, "security": false},
					{"version": "v21.0.0", "date": "2023-10-17", "files": [], "lts": false, "security": false},
					{"version": "v20.11.0", "date": "2024-01-09", "files": [], "lts": "Iron", "security": false},
					{"version": "v18.19.0", "date": "2023-11-29", "files": [], "lts": "Hydrogen", "security": false},
					{"version": "v16.20.2", "date": "2023-08-08", "files": [], "lts": "Gallium", "security": true},
					{"version": "v14.21.3", "date": "2023-02-16", "files": [], "lts": "Fermium", "security": true},
					{"version": "v12.22.12", "date": "2022-04-05", "files": [], "lts": "Erbium", "security": true}
				]`
				mockClient.responses["https://nodejs.org/dist/index.json"] = indexJSON
				watcher = watchers.NewNodeWatcher(mockClient)
			})

			It("includes all even-numbered major versions >= 12 regardless of LTS status", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				refs := make([]string, len(versions))
				for i, v := range versions {
					refs[i] = v.Ref
				}

				Expect(refs).To(ContainElement("12.22.12"))
				Expect(refs).To(ContainElement("14.21.3"))
				Expect(refs).To(ContainElement("16.20.2"))
				Expect(refs).To(ContainElement("18.19.0"))
				Expect(refs).To(ContainElement("20.11.0"))
				Expect(refs).To(ContainElement("22.0.0"))
			})

			It("excludes odd-numbered major versions", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())

				refs := make([]string, len(versions))
				for i, v := range versions {
					refs[i] = v.Ref
				}

				Expect(refs).NotTo(ContainElement("21.0.0"))
			})
		})
	})
})
