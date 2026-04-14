package watchers_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

var _ = Describe("ZuluWatcher", func() {
	var (
		client  *MockHTTPClient
		watcher *watchers.ZuluWatcher
	)

	BeforeEach(func() {
		client = &MockHTTPClient{}
	})

	Describe("Check", func() {
		Context("when the API returns valid release data", func() {
			It("returns the version", func() {
				client.Response = `[{
					"java_version": [8, 0, 302],
					"download_url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"name": "zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"latest": true
				}]`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("8.0.302"))
			})
		})

		Context("when version is not specified (latest-line check)", func() {
			It("returns all available major-version lines", func() {
				client.Response = `[
					{
						"java_version": [8, 0, 302],
						"download_url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jre8.0.302-linux_x64.tar.gz",
						"name": "zulu8.56.0.21-ca-jre8.0.302-linux_x64.tar.gz",
						"latest": true
					},
					{
						"java_version": [11, 0, 12],
						"download_url": "https://cdn.azul.com/zulu/bin/zulu11.50.19-ca-jre11.0.12-linux_x64.tar.gz",
						"name": "zulu11.50.19-ca-jre11.0.12-linux_x64.tar.gz",
						"latest": true
					}
				]`
				watcher = watchers.NewZuluWatcher(client, "", "jre")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				refs := []string{versions[0].Ref, versions[1].Ref}
				Expect(refs).To(ContainElements("8.0.302", "11.0.12"))
			})
		})

		Context("when type is missing", func() {
			It("returns an error", func() {
				watcher = watchers.NewZuluWatcher(client, "8", "")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("type must be specified"))
			})
		})

		Context("when version has invalid number of components", func() {
			It("returns an error", func() {
				client.Response = `[{
					"java_version": [8, 0],
					"download_url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"name": "zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"latest": true
				}]`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version must have three components"))
			})
		})
	})

	Describe("In", func() {
		Context("when version matches", func() {
			It("returns the release details", func() {
				client.Response = `[{
					"java_version": [8, 0, 302],
					"download_url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"name": "zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"latest": true
				}]`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				release, err := watcher.In("8.0.302")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("8.0.302"))
				Expect(release.URL).To(Equal("https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"))
			})
		})

		Context("when version does not match", func() {
			It("returns an error", func() {
				client.Response = `[{
					"java_version": [8, 0, 302],
					"download_url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"name": "zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz",
					"latest": true
				}]`
				watcher = watchers.NewZuluWatcher(client, "8", "jdk")

				_, err := watcher.In("8.0.999")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("version mismatch"))
			})
		})
	})
})
