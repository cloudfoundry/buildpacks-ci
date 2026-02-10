package watchers_test

import (

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)




var _ = Describe("ArtifactoryWatcher", func() {
	var (
		client *MockHTTPClient
	)

	BeforeEach(func() {
		client = &MockHTTPClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid results", func() {
			It("returns sorted versions", func() {
				client.Response = `{
					"results": [
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
							"path": "com/example/app/1.2.3/app-1.2.3.jar"
						},
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
							"path": "com/example/app/1.2.4/app-1.2.4.jar"
						},
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.3.0-SNAPSHOT/app-1.3.0-SNAPSHOT.jar",
							"path": "com/example/app/1.3.0-SNAPSHOT/app-1.3.0-SNAPSHOT.jar"
						}
					]
				}`
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(3))
				Expect(versions[0].Ref).To(Equal("1.2.3"))
				Expect(versions[1].Ref).To(Equal("1.2.4"))
				Expect(versions[2].Ref).To(Equal("1.3.0-SNAPSHOT"))
			})
		})

		Context("when artifact pattern is specified", func() {
			It("filters results by pattern", func() {
				client.Response = `{
					"results": [
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
							"path": "com/example/app/1.2.3/app-1.2.3.jar"
						},
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3-sources.jar",
							"path": "com/example/app/1.2.3/app-1.2.3-sources.jar"
						},
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
							"path": "com/example/app/1.2.4/app-1.2.4.jar"
						}
					]
				}`
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", ".*\\.jar$", "", "")
				Expect(err).NotTo(HaveOccurred())

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(len(versions)).To(BeNumerically(">=", 2))
			})
		})

		Context("when URI is missing", func() {
			It("returns an error", func() {
				watcher, err := watchers.NewArtifactoryWatcher(client, "", "com.example", "app", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				_, err = watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("uri must be specified"))
			})
		})

		Context("when group ID is missing", func() {
			It("returns an error", func() {
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "", "app", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				_, err = watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("group_id must be specified"))
			})
		})

		Context("when artifact ID is missing", func() {
			It("returns an error", func() {
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				_, err = watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("artifact_id must be specified"))
			})
		})

		Context("when repository is missing", func() {
			It("returns an error", func() {
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				_, err = watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("repository must be specified"))
			})
		})

		Context("when artifact pattern is invalid", func() {
			It("returns an error during construction", func() {
				_, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "[invalid", "", "")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("invalid artifact pattern"))
			})
		})
	})

	Describe("In", func() {
		Context("when version is found", func() {
			It("returns the release details", func() {
				client.Response = `{
					"results": [
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
							"path": "com/example/app/1.2.3/app-1.2.3.jar"
						},
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
							"path": "com/example/app/1.2.4/app-1.2.4.jar"
						}
					]
				}`
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				release, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
				Expect(release.URL).To(Equal("https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar"))
			})
		})

		Context("when version is not found", func() {
			It("returns an error", func() {
				client.Response = `{
					"results": [
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
							"path": "com/example/app/1.2.3/app-1.2.3.jar"
						}
					]
				}`
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
				Expect(err).NotTo(HaveOccurred())

				_, err = watcher.In("9.9.9")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not find version"))
			})
		})

		Context("when authentication is provided", func() {
			It("returns the release details", func() {
				client.Response = `{
					"results": [
						{
							"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
							"path": "com/example/app/1.2.3/app-1.2.3.jar"
						}
					]
				}`
				watcher, err := watchers.NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "user", "pass")
				Expect(err).NotTo(HaveOccurred())

				release, err := watcher.In("1.2.3")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("1.2.3"))
			})
		})
	})
})
