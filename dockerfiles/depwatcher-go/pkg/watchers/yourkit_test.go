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
		Context("when the HTML contains valid download links", func() {
			It("returns all versions found", func() {
				client.Response = `<html><body>
					<a href="/yjp/2022/YourKit-JavaProfiler-2022.9-b238-x64.zip">Download</a>
					<a href="/yjp/2022/YourKit-JavaProfiler-2022.3-b237-x64.zip">Download</a>
					<a href="/yjp/2021/YourKit-JavaProfiler-2021.11-b236-x64.zip">Download</a>
				</body></html>`

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
			})
		})
	})

	Describe("In", func() {
		It("returns the release details for a specific version", func() {
			release, err := watcher.In("2022.9.238")
			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("2022.9.238"))
			Expect(release.URL).To(Equal("https://download.yourkit.com/yjp/2022.9/YourKit-JavaProfiler-2022.9-b238-x64.zip"))
		})
	})
})
