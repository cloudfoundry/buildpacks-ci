package watchers_test

import (

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)




var _ = Describe("LibericaWatcher", func() {
	var (
		client  *MockHTTPClient
		watcher *watchers.LibericaWatcher
	)

	BeforeEach(func() {
		client = &MockHTTPClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid releases", func() {
			It("returns sorted versions", func() {
				client.Response = `[
					{
						"featureVersion": 8,
						"interimVersion": 0,
						"updateVersion": 302,
						"buildVersion": 8,
						"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
					},
					{
						"featureVersion": 8,
						"interimVersion": 0,
						"updateVersion": 292,
						"buildVersion": 10,
						"downloadUrl": "https://download.bell-sw.com/java/8u292+10/bellsoft-jdk8u292+10-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "8", "jdk", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("8.0.292+10"))
				Expect(versions[1].Ref).To(Equal("8.0.302+8"))
			})
		})

		Context("when version is missing", func() {
			It("returns an error", func() {
				watcher = watchers.NewLibericaWatcher(client, "", "jdk", "")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version must be specified"))
			})
		})

		Context("when type is missing", func() {
			It("returns an error", func() {
				watcher = watchers.NewLibericaWatcher(client, "8", "", "")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("type must be specified"))
			})
		})
	})

	Describe("In", func() {
		Context("when version is found", func() {
			It("returns the release details", func() {
				client.Response = `[
					{
						"featureVersion": 8,
						"interimVersion": 0,
						"updateVersion": 302,
						"buildVersion": 8,
						"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "8", "jdk", "")

				release, err := watcher.In("8.0.302+8")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.0.302+8"))
				Expect(release.URL).To(Equal("https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"))
			})
		})

		Context("when version is not found", func() {
			It("returns an error", func() {
				client.Response = `[
					{
						"featureVersion": 8,
						"interimVersion": 0,
						"updateVersion": 302,
						"buildVersion": 8,
						"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "8", "jdk", "")

				_, err := watcher.In("8.0.999+1")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find release for version"))
			})
		})
	})
})
