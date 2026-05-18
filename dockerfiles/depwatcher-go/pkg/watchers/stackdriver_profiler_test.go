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

const gcsListURL = "https://storage.googleapis.com/storage/v1/b/cloud-profiler/o?prefix=java%2Fcloud-profiler-java-agent_&maxResults=1000"
const profilerDownloadBase = "https://storage.googleapis.com/cloud-profiler/java/"

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
				gcsJSON := `{"items": [
					{"name": "java/cloud-profiler-java-agent_20240205_RC00.tar.gz"},
					{"name": "java/cloud-profiler-java-agent_20241028_RC00.tar.gz"},
					{"name": "java/cloud-profiler-java-agent_20240215_RC00.tar.gz"},
					{"name": "java/cloud-profiler-java-agent_20241028_RC00_alpine.tar.gz"},
					{"name": "java/latest/profiler_java_agent.tar.gz"}
				]}`

				client.responses[gcsListURL] = mockResponse{body: gcsJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("20240205_RC00"))
				Expect(versions[1].Ref).To(Equal("20240215_RC00"))
				Expect(versions[2].Ref).To(Equal("20241028_RC00"))
			})

			It("excludes alpine variants", func() {
				gcsJSON := `{"items": [
					{"name": "java/cloud-profiler-java-agent_20241028_RC00.tar.gz"},
					{"name": "java/cloud-profiler-java-agent_20241028_RC00_alpine.tar.gz"}
				]}`

				client.responses[gcsListURL] = mockResponse{body: gcsJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("20241028_RC00"))
			})
		})

		Context("when there are more than 10 versions", func() {
			It("returns only the 10 most recent", func() {
				var items []string
				for i := 1; i <= 12; i++ {
					items = append(items, fmt.Sprintf(`{"name": "java/cloud-profiler-java-agent_202401%02d_RC00.tar.gz"}`, i))
				}
				gcsJSON := fmt.Sprintf(`{"items": [%s]}`, strings.Join(items, ","))

				client.responses[gcsListURL] = mockResponse{body: gcsJSON, status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(10))
				Expect(versions[0].Ref).To(Equal("20240103_RC00"))
				Expect(versions[9].Ref).To(Equal("20240112_RC00"))
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
			It("returns the release with URL and computed SHA256", func() {
				tarURL := profilerDownloadBase + "cloud-profiler-java-agent_20241028_RC00.tar.gz"
				client.responses[tarURL] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("20241028_RC00")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("20241028_RC00"))
				Expect(release.URL).To(Equal(tarURL))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("20241028_RC00")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download Cloud Profiler agent"))
			})
		})
	})
})
