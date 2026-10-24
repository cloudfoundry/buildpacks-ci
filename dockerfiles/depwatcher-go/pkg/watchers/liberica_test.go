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
		It("preserves the existing zero-build version format", func() {
			client.Response = `[
				{"featureVersion": 21, "interimVersion": 0, "updateVersion": 12, "patchVersion": 0, "buildVersion": 0, "downloadUrl": "https://example.com/b0"}
			]`
			watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

			versions, err := watcher.Check()
			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("21.0.12+0"))

			release, err := watcher.In(versions[0].Ref)
			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal(versions[0].Ref))
			Expect(release.URL).To(Equal("https://example.com/b0"))
		})

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

		Context("when the API returns monthly patch releases (patchVersion)", func() {
			It("includes the patch version and sorts it after the quarterly release", func() {
				client.Response = `[
					{
						"featureVersion": 21,
						"interimVersion": 0,
						"updateVersion": 12,
						"patchVersion": 1,
						"buildVersion": 1,
						"downloadUrl": "https://github.com/bell-sw/Liberica/releases/download/21.0.12.1+1/bellsoft-jre21.0.12.1+1-linux-amd64.tar.gz"
					},
					{
						"featureVersion": 21,
						"interimVersion": 0,
						"updateVersion": 12,
						"patchVersion": 0,
						"buildVersion": 10,
						"downloadUrl": "https://github.com/bell-sw/Liberica/releases/download/21.0.12+10/bellsoft-jre21.0.12+10-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("21.0.12+10"))
				Expect(versions[1].Ref).To(Equal("21.0.12.1+1"))
			})

			It("sorts rebuilds of a patch release by build number", func() {
				client.Response = `[
					{"featureVersion": 17, "interimVersion": 0, "updateVersion": 20, "patchVersion": 1, "buildVersion": 10, "downloadUrl": "https://example.com/b10"},
					{"featureVersion": 17, "interimVersion": 0, "updateVersion": 20, "patchVersion": 1, "buildVersion": 9, "downloadUrl": "https://example.com/b9"}
				]`
				watcher = watchers.NewLibericaWatcher(client, "17", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))
				Expect(versions[0].Ref).To(Equal("17.0.20.1+9"))
				Expect(versions[1].Ref).To(Equal("17.0.20.1+10"))
			})
		})

		Context("when the API returns a security respin release (extraVersion)", func() {
			It("includes the extra version segment, not just patchVersion", func() {
				// Real BellSoft payload shape for the 2026-10-23 eMudhra
				// distrust respin: patchVersion is 0, the extra digit lives
				// in extraVersion, and the API's own "version" field already
				// has it right ("21.0.13.0.2+5").
				client.Response = `[
					{
						"featureVersion": 21,
						"interimVersion": 0,
						"updateVersion": 13,
						"patchVersion": 0,
						"extraVersion": 2,
						"buildVersion": 5,
						"version": "21.0.13.0.2+5",
						"downloadUrl": "https://github.com/bell-sw/Liberica/releases/download/21.0.13.0.2+5/bellsoft-jre21.0.13.0.2+5-linux-amd64.tar.gz"
					},
					{
						"featureVersion": 21,
						"interimVersion": 0,
						"updateVersion": 13,
						"patchVersion": 0,
						"extraVersion": 0,
						"buildVersion": 11,
						"version": "21.0.13+11",
						"downloadUrl": "https://github.com/bell-sw/Liberica/releases/download/21.0.13+11/bellsoft-jre21.0.13+11-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(2))

				var refs []string
				for _, v := range versions {
					refs = append(refs, v.Ref)
				}
				Expect(refs).To(ContainElement("21.0.13+11"))
				Expect(refs).To(ContainElement("21.0.13.0.2+5"))

				release, err := watcher.In("21.0.13.0.2+5")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://github.com/bell-sw/Liberica/releases/download/21.0.13.0.2+5/bellsoft-jre21.0.13.0.2+5-linux-amd64.tar.gz"))
			})
		})

		Context("when the API returns a Java 8 release (legacy 8uNNN version field)", func() {
			It("ignores the non-dotted version field and reconstructs from numeric fields instead", func() {
				// Real BellSoft payload shape for Java 8: "version" uses the
				// legacy "8uNNN+build" scheme, not the dotted JEP 322 form
				// used by 9+. Trusting it verbatim would emit "8u504+1"
				// instead of "8.0.504+1".
				client.Response = `[
					{"featureVersion": 8, "interimVersion": 0, "updateVersion": 504, "patchVersion": 0, "extraVersion": 0, "buildVersion": 1, "version": "8u504+1", "downloadUrl": "https://example.com/8u504"}
				]`
				watcher = watchers.NewLibericaWatcher(client, "8", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("8.0.504+1"))
			})
		})

		Context("when the API omits the version field (fallback reconstruction)", func() {
			It("still reconstructs a plain 3-field version", func() {
				client.Response = `[
					{"featureVersion": 17, "interimVersion": 0, "updateVersion": 20, "buildVersion": 10, "downloadUrl": "https://example.com/b"}
				]`
				watcher = watchers.NewLibericaWatcher(client, "17", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("17.0.20+10"))
			})

			It("still reconstructs an extraVersion respin when version is absent", func() {
				client.Response = `[
					{"featureVersion": 21, "interimVersion": 0, "updateVersion": 13, "patchVersion": 0, "extraVersion": 2, "buildVersion": 5, "downloadUrl": "https://example.com/respin"}
				]`
				watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("21.0.13.0.2+5"))
			})

			It("does not insert a spurious zero when both patchVersion and extraVersion are positive", func() {
				client.Response = `[
					{"featureVersion": 21, "interimVersion": 0, "updateVersion": 13, "patchVersion": 1, "extraVersion": 2, "buildVersion": 5, "downloadUrl": "https://example.com/both"}
				]`
				watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("21.0.13.1.2+5"))
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

		Context("when the version is a monthly patch release", func() {
			It("returns the release details", func() {
				client.Response = `[
					{
						"featureVersion": 21,
						"interimVersion": 0,
						"updateVersion": 12,
						"patchVersion": 1,
						"buildVersion": 1,
						"downloadUrl": "https://github.com/bell-sw/Liberica/releases/download/21.0.12.1+1/bellsoft-jre21.0.12.1+1-linux-amd64.tar.gz"
					}
				]`
				watcher = watchers.NewLibericaWatcher(client, "21", "jre", "")

				release, err := watcher.In("21.0.12.1+1")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("21.0.12.1+1"))
				Expect(release.URL).To(Equal("https://github.com/bell-sw/Liberica/releases/download/21.0.12.1+1/bellsoft-jre21.0.12.1+1-linux-amd64.tar.gz"))
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
