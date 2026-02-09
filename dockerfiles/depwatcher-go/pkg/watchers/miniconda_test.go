package watchers_test

import (
	"io"
	"net/http"
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type mockMinicondaClient struct {
	htmlResponse string
}

func (m *mockMinicondaClient) Get(url string) (*http.Response, error) {
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(m.htmlResponse)),
	}, nil
}

func (m *mockMinicondaClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("MinicondaWatcher", func() {
	var (
		watcher *watchers.MinicondaWatcher
		client  *mockMinicondaClient
	)

	BeforeEach(func() {
		client = &mockMinicondaClient{}
	})

	Context("Check", func() {
		It("extracts versions for py39 from HTML table sorted", func() {
			fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/miniconda.html")
			Expect(err).NotTo(HaveOccurred())
			client.htmlResponse = string(fixtureData)

			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(6))
			Expect(versions[0].Ref).To(Equal("22.11.1"))
			Expect(versions[1].Ref).To(Equal("23.1.0"))
			Expect(versions[2].Ref).To(Equal("23.3.1"))
			Expect(versions[3].Ref).To(Equal("23.5.0"))
			Expect(versions[4].Ref).To(Equal("23.5.1"))
			Expect(versions[5].Ref).To(Equal("23.5.2"))
		})

		It("extracts versions for py38 from HTML table sorted", func() {
			fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/miniconda.html")
			Expect(err).NotTo(HaveOccurred())
			client.htmlResponse = string(fixtureData)

			watcher = watchers.NewMinicondaWatcher(client, "3.8")
			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(6))
			Expect(versions[0].Ref).To(Equal("22.11.1"))
			Expect(versions[1].Ref).To(Equal("23.1.0"))
			Expect(versions[2].Ref).To(Equal("23.3.1"))
			Expect(versions[3].Ref).To(Equal("23.5.0"))
			Expect(versions[4].Ref).To(Equal("23.5.1"))
			Expect(versions[5].Ref).To(Equal("23.5.2"))
		})

		It("only matches Linux x86_64 builds", func() {
			client.htmlResponse = `
				<html>
					<table>
						<tr>
							<td><a href="Miniconda3-py39_23.1.0-1-Windows-x86_64.exe">Windows</a></td>
							<td class="s">52.9M</td>
							<td>2023-02-07 21:27:23</td>
							<td>a2e7ec485e5412673fad31e6a5a79f9de73792e7c966764f92eabf25ec37557f</td>
						</tr>
						<tr>
							<td><a href="Miniconda3-py39_23.1.0-1-Linux-x86_64.sh">Linux</a></td>
							<td class="s">66.7M</td>
							<td>2023-02-07 21:27:23</td>
							<td>5dc619babc1d19d6688617966251a38d245cb93d69066ccde9a013e1ebb5bf18</td>
						</tr>
						<tr>
							<td><a href="Miniconda3-py39_23.1.0-1-MacOSX-x86_64.sh">MacOS</a></td>
							<td class="s">43.3M</td>
							<td>2023-02-07 21:27:23</td>
							<td>d78eaac94f85bacbc704f629bdfbc2cd42a72dc3a4fd383a3bfc80997495320e</td>
						</tr>
					</table>
				</html>
			`

			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			versions, err := watcher.Check()

			Expect(err).NotTo(HaveOccurred())
			Expect(versions).To(HaveLen(1))
			Expect(versions[0].Ref).To(Equal("23.1.0"))
		})

		It("returns error when no releases found for python version", func() {
			client.htmlResponse = `
				<html>
					<table>
						<tr>
							<td><a href="Miniconda3-py311_23.1.0-1-Linux-x86_64.sh">Linux</a></td>
							<td class="s">73.2M</td>
							<td>2023-02-07 21:27:22</td>
							<td>d4517212c8ac44fd8b5ccc2d4d9f38c2dd924c77a81c2be92c3a72e70dd3e907</td>
						</tr>
					</table>
				</html>
			`

			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			_, err := watcher.Check()

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("no releases found for Python version 3.9"))
		})

		It("returns error when pythonVersion is empty", func() {
			client.htmlResponse = `<html><table></table></html>`

			watcher = watchers.NewMinicondaWatcher(client, "")
			_, err := watcher.Check()

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("python_version is required"))
		})

		It("returns error when pythonVersion is invalid format", func() {
			client.htmlResponse = `<html><table></table></html>`

			watcher = watchers.NewMinicondaWatcher(client, "3")
			_, err := watcher.Check()

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("python_version must be in format 'X.Y'"))
		})
	})

	Context("In", func() {
		BeforeEach(func() {
			fixtureData, err := os.ReadFile("../../../depwatcher/spec/fixtures/miniconda.html")
			Expect(err).NotTo(HaveOccurred())
			client.htmlResponse = string(fixtureData)
		})

		It("returns release details for py39 version 23.1.0", func() {
			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			release, err := watcher.In("23.1.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("23.1.0"))
			Expect(release.URL).To(Equal("https://repo.anaconda.com/miniconda/Miniconda3-py39_23.1.0-1-Linux-x86_64.sh"))
			Expect(release.SHA256).To(Equal("5dc619babc1d19d6688617966251a38d245cb93d69066ccde9a013e1ebb5bf18"))
		})

		It("returns release details for py38 version 23.1.0", func() {
			watcher = watchers.NewMinicondaWatcher(client, "3.8")
			release, err := watcher.In("23.1.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.Ref).To(Equal("23.1.0"))
			Expect(release.URL).To(Equal("https://repo.anaconda.com/miniconda/Miniconda3-py38_23.1.0-1-Linux-x86_64.sh"))
			Expect(release.SHA256).To(Equal("640b7dceee6fad10cb7e7b54667b2945c4d6f57625d062b2b0952b7f3a908ab7"))
		})

		It("returns error when version not found", func() {
			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			_, err := watcher.In("99.99.99")

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("version 99.99.99 not found"))
		})

		It("constructs correct URL with build number", func() {
			watcher = watchers.NewMinicondaWatcher(client, "3.9")
			release, err := watcher.In("23.5.0")

			Expect(err).NotTo(HaveOccurred())
			Expect(release.URL).To(Equal("https://repo.anaconda.com/miniconda/Miniconda3-py39_23.5.0-3-Linux-x86_64.sh"))
		})
	})
})
