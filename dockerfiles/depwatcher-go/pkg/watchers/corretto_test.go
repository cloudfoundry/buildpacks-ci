package watchers_test

import (

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)




var _ = Describe("CorrettoWatcher", func() {
	var (
		client  *MockHTTPClient
		watcher *watchers.CorrettoWatcher
	)

	BeforeEach(func() {
		client = &MockHTTPClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid releases", func() {
			It("returns sorted versions excluding drafts and prereleases", func() {
				client.Response = `[
					{"tag_name": "8.302.08.1", "draft": false, "prerelease": false},
					{"tag_name": "8.292.10.1", "draft": false, "prerelease": false},
					{"tag_name": "11.0.12.7.1", "draft": false, "prerelease": false},
					{"tag_name": "16.0.2.7.1", "draft": false, "prerelease": false},
					{"tag_name": "draft-version", "draft": true, "prerelease": false},
					{"tag_name": "prerelease-version", "draft": false, "prerelease": true}
				]`
				watcher = watchers.NewCorrettoWatcher(client, "corretto", "corretto-8")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).NotTo(BeEmpty())
				Expect(versions).To(HaveLen(4))

				// Verify version format conversion
				Expect(versions[0].Ref).To(Equal("8.292.10-1"))
				Expect(versions[1].Ref).To(Equal("8.302.08-1"))
				Expect(versions[2].Ref).To(Equal("11.0.12-7.1"))
				Expect(versions[3].Ref).To(Equal("16.0.2-7.1"))
			})
		})

		Context("when the API returns invalid JSON", func() {
			It("returns an error", func() {
				client.Response = "invalid json"
				watcher = watchers.NewCorrettoWatcher(client, "corretto", "corretto-8")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
			})
		})
	})

	Describe("In", func() {
		Context("when version has standard format", func() {
			It("returns the release details with converted URL", func() {
				watcher = watchers.NewCorrettoWatcher(client, "corretto", "corretto-8")

				release, err := watcher.In("8.302.08-1")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.302.08-1"))
				Expect(release.URL).To(Equal("https://corretto.aws/downloads/resources/8.302.08.1/amazon-corretto-8.302.08.1-linux-x64.tar.gz"))
			})
		})

		Context("when version has multi-part build version", func() {
			It("returns the release details with converted URL", func() {
				watcher = watchers.NewCorrettoWatcher(client, "corretto", "corretto-11")

				release, err := watcher.In("11.0.12-7.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("11.0.12-7.1"))
				Expect(release.URL).To(Equal("https://corretto.aws/downloads/resources/11.0.12.7.1/amazon-corretto-11.0.12.7.1-linux-x64.tar.gz"))
			})
		})
	})
})
