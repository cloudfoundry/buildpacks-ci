package watchers_test

import (
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AppDynamicsWatcher", func() {
	var (
		mockClient *MockHTTPClient
		watcher    *watchers.AppDynamicsWatcher
	)

	Describe("Check", func() {
		Context("when checking for java agent version", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfilelatest/": `[
							{
								"download_path": "https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip",
								"filetype": "java",
								"version": "23.11.0.35669",
								"sha256_checksum": "abc123def456"
							}
						]`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "java")
			})

			It("returns latest java agent version", func() {
				versions, err := watcher.Check()

				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("23.11.0-35669"))
			})
		})

		Context("when checking for machine agent version", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfilelatest/": `[
							{
								"download_path": "https://download.appdynamics.com/download/prox/download-file/machine/23.11.0.3826/appdynamics-machine-agent-23.11.0.3826.zip",
								"filetype": "machine",
								"version": "23.11.0.3826",
								"sha256_checksum": "def456ghi789"
							}
						]`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "machine")
			})

			It("returns latest machine agent version", func() {
				versions, err := watcher.Check()

				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("23.11.0-3826"))
			})
		})

		Context("when checking for php-tar agent version", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfilelatest/": `[
							{
								"download_path": "https://download.appdynamics.com/download/prox/download-file/php-tar/23.10.0.6006/appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2",
								"filetype": "php-tar",
								"version": "23.10.0.6006",
								"sha256_checksum": "ghi789jkl012"
							}
						]`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "php-tar")
			})

			It("returns latest php-tar agent version", func() {
				versions, err := watcher.Check()

				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("23.10.0-6006"))
			})
		})

		Context("when checking for unknown agent type", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfilelatest/": `[
							{
								"download_path": "https://example.com/agent.zip",
								"filetype": "java",
								"version": "23.11.0.35669",
								"sha256_checksum": "abc123def456"
							}
						]`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "unknown")
			})

			It("returns error for unknown agent type", func() {
				_, err := watcher.Check()

				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no version found for agent type unknown"))
			})
		})

		Context("when converting version format", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfilelatest/": `[
							{
								"filetype": "java",
								"version": "24.1.0.1234",
								"download_path": "https://example.com/agent.zip",
								"sha256_checksum": "abc123"
							}
						]`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "java")
			})

			It("converts version from X.Y.Z.W to X.Y.Z-W format", func() {
				versions, err := watcher.Check()

				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(1))
				Expect(versions[0].Ref).To(Equal("24.1.0-1234"))
			})
		})
	})

	Describe("In", func() {
		Context("when fetching java agent release details", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfile/?apm_os=linux&version=23.11.0.35669&apm=java": `{
							"count": 1,
							"results": [
								{
									"download_path": "https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip",
									"filetype": "java",
									"version": "23.11.0.35669",
									"sha256_checksum": "abc123def456"
								}
							]
						}`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "java")
			})

			It("returns java agent release details", func() {
				release, err := watcher.In("23.11.0-35669")

				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("23.11.0-35669"))
				Expect(release.URL).To(Equal("https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip"))
				Expect(release.SHA256).To(Equal("abc123def456"))
			})
		})

		Context("when fetching php-tar agent release details", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{
						"https://download.appdynamics.com/download/downloadfile/?apm_os=linux&version=23.10.0.6006&apm=php&filetype=tar": `{
							"count": 1,
							"results": [
								{
									"download_path": "https://download.appdynamics.com/download/prox/download-file/php-tar/23.10.0.6006/appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2",
									"filetype": "php-tar",
									"version": "23.10.0.6006",
									"sha256_checksum": "ghi789jkl012"
								}
							]
						}`,
					},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "php-tar")
			})

			It("returns php-tar agent release details", func() {
				release, err := watcher.In("23.10.0-6006")

				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("23.10.0-6006"))
				Expect(release.URL).To(ContainSubstring("appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2"))
				Expect(release.SHA256).To(Equal("ghi789jkl012"))
			})
		})

		Context("when handling invalid version format", func() {
			BeforeEach(func() {
				mockClient = &MockHTTPClient{
					Responses: map[string]string{},
				}
				watcher = watchers.NewAppDynamicsWatcher(mockClient, "java")
			})

			It("returns error for invalid version format", func() {
				_, err := watcher.In("invalid")

				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("invalid version format"))
			})
		})
	})
})
