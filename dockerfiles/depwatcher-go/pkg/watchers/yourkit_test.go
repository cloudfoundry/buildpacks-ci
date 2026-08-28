package watchers_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

var _ = Describe("YourKitWatcher", func() {
	var (
		client  *MockHTTPClient
		watcher *watchers.YourKitWatcher
	)

	BeforeEach(func() {
		client = &MockHTTPClient{}
		watcher = watchers.NewYourKitWatcher(client)
	})

	Describe("Check", func() {
		Context("when the archive page has old-style zip links and the download page has version/build text", func() {
			It("returns versions from both sources without duplicates", func() {
				client.Responses = map[string]string{
					"https://www.yourkit.com/download/archive.jsp": `<html><body>
						<a href="https://archive.yourkit.com/yjp/2025.9/YourKit-JavaProfiler-2025.9-b191-x64.zip">Download</a>
						<a href="https://archive.yourkit.com/yjp/2025.3/YourKit-JavaProfiler-2025.3-b154-x64.zip">Download</a>
					</body></html>`,
					"https://www.yourkit.com/download/": `<html><body>
						<p>Version: 2026.3</p>
						<p>Build: #176</p>
					</body></html>`,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("2025.3.154"))
				Expect(versions[1].Ref).To(Equal("2025.9.191"))
				Expect(versions[2].Ref).To(Equal("2026.3.176"))
			})
		})

		Context("when the download page has no version/build info", func() {
			It("returns only archive versions", func() {
				client.Responses = map[string]string{
					"https://www.yourkit.com/download/archive.jsp": `<html><body>
						<a href="https://archive.yourkit.com/yjp/2025.9/YourKit-JavaProfiler-2025.9-b191-x64.zip">Download</a>
					</body></html>`,
					"https://www.yourkit.com/download/": `<html><body><p>No version info</p></body></html>`,
				}

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("2025.9.191"))
			})
		})
	})

	Describe("In", func() {
		Context("when the new-style URL is available", func() {
			It("returns the new-style URL for a 2026+ version", func() {
				client.Responses = map[string]string{
					"https://download.yourkit.com/yjp/2026.3.176/YourKit-Java-Profiler-2026.3.176-x64.zip": "",
				}
				client.StatusCode = 200

				release, err := watcher.In("2026.3.176")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("2026.3.176"))
				Expect(release.URL).To(Equal("https://download.yourkit.com/yjp/2026.3.176/YourKit-Java-Profiler-2026.3.176-x64.zip"))
			})
		})

		Context("when the new-style URL is not available", func() {
			It("falls back to the old-style archive URL", func() {
				client.StatusCode = 404

				release, err := watcher.In("2025.9.191")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("2025.9.191"))
				Expect(release.URL).To(Equal("https://archive.yourkit.com/yjp/2025.9/YourKit-JavaProfiler-2025.9-b191-x64.zip"))
			})
		})
	})
})

