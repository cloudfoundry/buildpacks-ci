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

type mockStackdriverProfilerClient struct {
	responses map[string]mockResponse
}

func (m *mockStackdriverProfilerClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockStackdriverProfilerClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockStackdriverProfilerClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

const gcsListURL = "https://storage.googleapis.com/storage/v1/b/cloud-profiler/o?prefix=java%2F&maxResults=1000&fields=items(name,md5Hash)"
const profilerDownloadBase = "https://storage.googleapis.com/cloud-profiler/java/"

const latestObject = "java/latest/profiler_java_agent.tar.gz"

// gcsList builds a bucket listing from "name" or "name|md5" entries.
func gcsList(entries ...string) string {
	items := make([]string, len(entries))
	for i, entry := range entries {
		name, md5, _ := strings.Cut(entry, "|")
		items[i] = fmt.Sprintf(`{"name": %q, "md5Hash": %q}`, name, md5)
	}
	return fmt.Sprintf(`{"items": [%s]}`, strings.Join(items, ","))
}

var _ = Describe("StackdriverProfilerWatcher", func() {
	var (
		client  *mockStackdriverProfilerClient
		watcher *watchers.StackdriverProfilerWatcher
	)

	BeforeEach(func() {
		client = &mockStackdriverProfilerClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewStackdriverProfilerWatcher(client)
	})

	Describe("Check", func() {
		Context("when the GCS API returns objects", func() {
			It("returns sorted non-alpine versions", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20240205_RC00.tar.gz|old",
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|newest",
					"java/cloud-profiler-java-agent_20240215_RC00.tar.gz|old",
					"java/cloud-profiler-java-agent_20241028_RC00_alpine.tar.gz|alpine",
					latestObject+"|newest",
				)}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("0.20240205.0"))
				Expect(versions[1].Ref).To(Equal("0.20240215.0"))
				Expect(versions[2].Ref).To(Equal("0.20241028.0"))
			})

			It("orders release candidates of the same day by their number, not as text", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC10.tar.gz|newest",
					"java/cloud-profiler-java-agent_20241028_RC02.tar.gz|old",
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|old",
					latestObject+"|newest",
				)}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("0.20241028.0"))
				Expect(versions[1].Ref).To(Equal("0.20241028.2"))
				Expect(versions[2].Ref).To(Equal("0.20241028.10"))
			})

			It("excludes alpine variants", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|newest",
					"java/cloud-profiler-java-agent_20241028_RC00_alpine.tar.gz|alpine",
					latestObject+"|newest",
				)}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("0.20241028.0"))
			})
		})

		Context("when the bucket has a release name in an unknown format", func() {
			It("fails instead of silently skipping the release", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|newest",
					"java/cloud-profiler-java-agent_20270105_hotfix1.tar.gz|other",
					latestObject+"|newest",
				)}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected Cloud Profiler agent file name"))
				Expect(err.Error()).To(ContainSubstring("cloud-profiler-java-agent_20270105_hotfix1.tar.gz"))
			})

			It("accepts alpine variants and objects that are not release tarballs", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|newest",
					"java/cloud-profiler-java-agent_20241028_RC00_alpine.tar.gz|alpine",
					"java/staging/profiler_java_agent.tar.gz|staging",
					"java/test/profiler_java_agent.tar.gz|test",
					latestObject+"|newest",
				)}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
			})
		})

		Context("when the floating latest copy differs from the newest release", func() {
			It("fails, because a release was published without a dated file name", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|aaa",
					latestObject+"|bbb",
				)}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("latest"))
				Expect(err.Error()).To(ContainSubstring("cloud-profiler-java-agent_20241028_RC00.tar.gz"))
			})

			It("compares with the newest release, not with an older one", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|new",
					"java/cloud-profiler-java-agent_20240215_RC00.tar.gz|old",
					latestObject+"|old",
				)}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
			})

			It("fails when the latest copy is missing from the bucket", func() {
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(
					"java/cloud-profiler-java-agent_20241028_RC00.tar.gz|newest",
				)}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("latest"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the 10 most recent", func() {
				var entries []string
				for i := 1; i <= 12; i++ {
					md5 := "old"
					if i == 12 {
						md5 = "newest"
					}
					entries = append(entries, fmt.Sprintf("java/cloud-profiler-java-agent_202401%02d_RC00.tar.gz|%s", i, md5))
				}
				entries = append(entries, latestObject+"|newest")
				client.responses[gcsListURL] = mockResponse{status: 200, body: gcsList(entries...)}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("0.20240103.0"))
				Expect(versions[9].Ref).To(Equal("0.20240112.0"))
			})
		})

		Context("when no versions are found", func() {
			It("returns an error", func() {
				client.responses[gcsListURL] = mockResponse{body: `{"items": []}`, status: 200}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no Cloud Profiler Java agent versions found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch Cloud Profiler agent list"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("downloads the artifact of the date version and returns the release with a semver Ref", func() {
				tarURL := profilerDownloadBase + "cloud-profiler-java-agent_20241028_RC00.tar.gz"
				client.responses[tarURL] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("0.20241028.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("0.20241028.0"))
				Expect(release.URL).To(Equal(tarURL))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})

			It("pads the release candidate number to two digits", func() {
				tarURL := profilerDownloadBase + "cloud-profiler-java-agent_20241028_RC03.tar.gz"
				client.responses[tarURL] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("0.20241028.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal(tarURL))
			})

			It("still accepts a date version that was published before the semver form existed", func() {
				tarURL := profilerDownloadBase + "cloud-profiler-java-agent_20241028_RC00.tar.gz"
				client.responses[tarURL] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("20241028_RC00")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("0.20241028.0"))
				Expect(release.URL).To(Equal(tarURL))
			})
		})

		Context("when the version has an unexpected form", func() {
			It("returns an error without downloading anything", func() {
				_, err := watcher.In("1.2.3")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected Cloud Profiler agent version"))
			})

			It("does not accept the floating latest label", func() {
				_, err := watcher.In("latest")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected Cloud Profiler agent version"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("0.20241028.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download Cloud Profiler agent"))
			})
		})
	})
})
