package watchers_test

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockSealightsClient struct {
	responses map[string]mockResponse
}

func (m *mockSealightsClient) Get(url string) (*http.Response, error) {
	resp, exists := m.responses[url]
	if !exists {
		return nil, fmt.Errorf("unexpected URL: %s", url)
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
	}, nil
}

func (m *mockSealightsClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func (m *mockSealightsClient) GetRaw(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

// buildZip creates an in-memory zip with a sealights-java-version.txt entry.
func buildZip(version string) string {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	w, _ := zw.Create("sealights-java-version.txt")
	w.Write([]byte(version))
	zw.Close()
	return buf.String()
}

const sealightsLatest = "https://agents.sealights.co/sealights-java/sealights-java-latest.zip"

var _ = Describe("SealightsAgentWatcher", func() {
	var (
		client  *mockSealightsClient
		watcher *watchers.SealightsAgentWatcher
	)

	BeforeEach(func() {
		client = &mockSealightsClient{responses: make(map[string]mockResponse)}
		watcher = watchers.NewSealightsAgentWatcher(client)
	})

	Describe("Check", func() {
		Context("when the latest zip contains a version file", func() {
			It("returns the version from sealights-java-version.txt", func() {
				client.responses[sealightsLatest] = mockResponse{body: buildZip("4.0.2778"), status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("4.0.2778"))
			})

			It("trims whitespace from the version", func() {
				client.responses[sealightsLatest] = mockResponse{body: buildZip("4.0.2778\n"), status: 200}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions[0].Ref).To(Equal("4.0.2778"))
			})
		})

		Context("when the latest zip has no version file", func() {
			It("returns an error", func() {
				var buf bytes.Buffer
				zw := zip.NewWriter(&buf)
				zw.Create("some-other-file.jar")
				zw.Close()

				client.responses[sealightsLatest] = mockResponse{body: buf.String(), status: 200}

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("sealights-java-version.txt not found"))
			})
		})

		Context("when the HTTP request fails", func() {
			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to fetch SeaLights latest zip"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching a specific version", func() {
			It("returns the release with URL and computed SHA256", func() {
				url := "https://agents.sealights.co/sealights-java/sealights-java-4.0.2778.zip"
				client.responses[url] = mockResponse{body: "hello", status: 200}

				release, err := watcher.In("4.0.2778")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("4.0.2778"))
				Expect(release.URL).To(Equal(url))
				Expect(release.SHA256).To(Equal("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
			})
		})

		Context("when the download fails", func() {
			It("returns an error", func() {
				_, err := watcher.In("4.0.2778")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to download SeaLights agent"))
			})
		})
	})
})
