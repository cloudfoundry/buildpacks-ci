package watchers_test

import (
	"net/http"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/ghttp"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

var _ = Describe("Dotnet Watchers", func() {
	var (
		server *ghttp.Server
	)

	BeforeEach(func() {
		server = ghttp.NewServer()
	})

	AfterEach(func() {
		server.Close()
	})

	Describe("DotnetSDKWatcher", func() {
		It("lists SDK versions from a channel", func() {
			releasesJSON := `{
				"releases": [
					{
						"sdk": {
							"version": "8.0.100",
							"files": [{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk.tar.gz", "hash": "abc123"}]
						},
						"runtime": {"version": "8.0.0"}
					},
					{
						"sdk": {
							"version": "8.0.101",
							"files": [{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk2.tar.gz", "hash": "def456"}]
						},
						"runtime": {"version": "8.0.1"}
					},
					{
						"sdk": {
							"version": "8.0.102-preview",
							"files": [{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk3.tar.gz", "hash": "ghi789"}]
						},
						"runtime": {"version": "8.0.2"}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetSDKWatcher(client)

			versions, err := watcher.Check("8.0.X")

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("8.0.101"))
			Expect(versions[1].Ref).To(Equal("8.0.100"))
		})

		It("fetches SDK release details", func() {
			releasesJSON := `{
				"releases": [
					{
						"sdk": {
							"version": "8.0.100",
							"files": [
								{"name": "dotnet-sdk-win-x64.zip", "url": "https://example.com/win.zip", "hash": "win123"},
								{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk.tar.gz", "hash": "ABC123"}
							]
						},
						"runtime": {"version": "8.0.0"}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetSDKWatcher(client)

			release, err := watcher.In("8.0.100")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("8.0.100"))
			Expect(release.URL).To(Equal("https://example.com/sdk.tar.gz"))
			Expect(release.SHA512).To(Equal("abc123"))
			Expect(release.RuntimeVersion).To(Equal("8.0.0"))
		})

		It("gets latest version when filter is empty", func() {
			indexJSON := `{
				"releases-index": [
					{"channel-version": "9.0", "support-phase": "active"},
					{"channel-version": "8.0", "support-phase": "lts"},
					{"channel-version": "7.0", "support-phase": "preview"}
				]
			}`

			releasesJSON := `{
				"releases": [
					{
						"sdk": {
							"version": "9.0.100",
							"files": [{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk.tar.gz", "hash": "abc123"}]
						},
						"runtime": {"version": "9.0.0"}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/releases-index.json"),
					ghttp.RespondWith(http.StatusOK, indexJSON),
				),
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/9.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetSDKWatcher(client)

			versions, err := watcher.Check("latest")

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("9.0.100"))
		})

		It("filters out preview and go-live releases from latest", func() {
			indexJSON := `{
				"releases-index": [
					{"channel-version": "10.0", "support-phase": "go-live"},
					{"channel-version": "9.0", "support-phase": "preview"},
					{"channel-version": "8.0", "support-phase": "lts"}
				]
			}`

			releasesJSON := `{
				"releases": [
					{
						"sdk": {
							"version": "8.0.100",
							"files": [{"name": "dotnet-sdk-linux-x64.tar.gz", "url": "https://example.com/sdk.tar.gz", "hash": "abc123"}]
						},
						"runtime": {"version": "8.0.0"}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/releases-index.json"),
					ghttp.RespondWith(http.StatusOK, indexJSON),
				),
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetSDKWatcher(client)

			versions, err := watcher.Check("")

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("8.0.100"))
		})
	})

	Describe("DotnetRuntimeWatcher", func() {
		It("lists runtime versions", func() {
			releasesJSON := `{
				"releases": [
					{
						"runtime": {
							"version": "8.0.0",
							"files": [{"name": "dotnet-runtime-linux-x64.tar.gz", "url": "https://example.com/runtime.tar.gz", "hash": "abc123"}]
						}
					},
					{
						"runtime": {
							"version": "8.0.1",
							"files": [{"name": "dotnet-runtime-linux-x64.tar.gz", "url": "https://example.com/runtime2.tar.gz", "hash": "def456"}]
						}
					},
					{
						"runtime": {
							"version": "8.0.2-preview",
							"files": [{"name": "dotnet-runtime-linux-x64.tar.gz", "url": "https://example.com/runtime3.tar.gz", "hash": "ghi789"}]
						}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetRuntimeWatcher(client)

			versions, err := watcher.Check("8.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("8.0.1"))
			Expect(versions[1].Ref).To(Equal("8.0.0"))
		})

		It("fetches runtime release details", func() {
			releasesJSON := `{
				"releases": [
					{
						"runtime": {
							"version": "8.0.0",
							"files": [
								{"name": "dotnet-runtime-win-x64.zip", "url": "https://example.com/win.zip", "hash": "win123"},
								{"name": "dotnet-runtime-linux-x64.tar.gz", "url": "https://example.com/runtime.tar.gz", "hash": "ABC123"}
							]
						}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetRuntimeWatcher(client)

			release, err := watcher.In("8.0.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("8.0.0"))
			Expect(release.URL).To(Equal("https://example.com/runtime.tar.gz"))
			Expect(release.SHA512).To(Equal("abc123"))
			Expect(release.RuntimeVersion).To(Equal("8.0.0"))
		})
	})

	Describe("DotnetAspnetcoreWatcher", func() {
		It("lists aspnetcore runtime versions", func() {
			releasesJSON := `{
				"releases": [
					{
						"aspnetcore-runtime": {
							"version": "8.0.0",
							"files": [{"name": "aspnetcore-runtime-linux-x64.tar.gz", "url": "https://example.com/aspnet.tar.gz", "hash": "abc123"}]
						}
					},
					{
						"aspnetcore-runtime": {
							"version": "8.0.1",
							"files": [{"name": "aspnetcore-runtime-linux-x64.tar.gz", "url": "https://example.com/aspnet2.tar.gz", "hash": "def456"}]
						}
					},
					{
						"aspnetcore-runtime": {
							"version": "8.0.2-rc1",
							"files": [{"name": "aspnetcore-runtime-linux-x64.tar.gz", "url": "https://example.com/aspnet3.tar.gz", "hash": "ghi789"}]
						}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetAspnetcoreWatcher(client)

			versions, err := watcher.Check("8.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(2))
			Expect(versions[0].Ref).To(Equal("8.0.1"))
			Expect(versions[1].Ref).To(Equal("8.0.0"))
		})

		It("fetches aspnetcore release details", func() {
			releasesJSON := `{
				"releases": [
					{
						"aspnetcore-runtime": {
							"version": "8.0.0",
							"files": [
								{"name": "aspnetcore-runtime-win-x64.zip", "url": "https://example.com/win.zip", "hash": "win123"},
								{"name": "aspnetcore-runtime-linux-x64.tar.gz", "url": "https://example.com/aspnet.tar.gz", "hash": "ABC123"}
							]
						}
					}
				]
			}`

			server.AppendHandlers(
				ghttp.CombineHandlers(
					ghttp.VerifyRequest("GET", "/release-notes/8.0/releases.json"),
					ghttp.RespondWith(http.StatusOK, releasesJSON),
				),
			)

			client := &mockHTTPClient{baseURL: server.URL()}
			watcher := watchers.NewDotnetAspnetcoreWatcher(client)

			release, err := watcher.In("8.0.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("8.0.0"))
			Expect(release.URL).To(Equal("https://example.com/aspnet.tar.gz"))
			Expect(release.SHA512).To(Equal("abc123"))
			Expect(release.RuntimeVersion).To(Equal("8.0.0"))
		})
	})
})

type mockHTTPClient struct {
	baseURL string
}

func (m *mockHTTPClient) Get(url string) (*http.Response, error) {
	modifiedURL := m.baseURL + "/" + url[len("https://raw.githubusercontent.com/dotnet/core/refs/heads/main/"):]
	return http.Get(modifiedURL)
}

func (m *mockHTTPClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}
