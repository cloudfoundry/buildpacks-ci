package watchers_test

import (
	"io"
	"net/http"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type mavenMockClient struct {
	response *http.Response
	err      error
}

func (m *mavenMockClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.response, nil
}

func (m *mavenMockClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

var _ = Describe("MavenWatcher", func() {
	var (
		watcher    *watchers.MavenWatcher
		mockClient *mavenMockClient
	)

	BeforeEach(func() {
		mockClient = &mavenMockClient{}
	})

	Describe("Check", func() {
		Context("when the metadata XML is valid", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body: io.NopCloser(strings.NewReader(`<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <versioning>
    <versions>
      <version>1.0.0</version>
      <version>1.1.0</version>
      <version>1.2.0</version>
      <version>2.0.0-RELEASE</version>
      <version>2.1.0-M1</version>
    </versions>
  </versioning>
</metadata>`)),
				}
				watcher = watchers.NewMavenWatcher(
					mockClient,
					"https://repo1.maven.org/maven2",
					"org.springframework",
					"spring-core",
					"",
					"jar",
					"",
					"",
				)
			})

			It("returns a list of versions sorted", func() {
				versions, err := watcher.Check()
				Expect(err).NotTo(HaveOccurred())
				Expect(versions).To(HaveLen(5))
				Expect(versions[0].Ref).To(Equal("1.0.0"))
				Expect(versions[1].Ref).To(Equal("1.1.0"))
				Expect(versions[2].Ref).To(Equal("1.2.0"))
				Expect(versions[3].Ref).To(Equal("2.0.0-RELEASE"))
				Expect(versions[4].Ref).To(Equal("2.1.0-M1"))
			})
		})

		Context("when URI is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(mockClient, "", "org.test", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("uri must be specified"))
			})
		})

		Context("when groupId is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(mockClient, "https://repo1.maven.org/maven2", "", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("group_id must be specified"))
			})
		})

		Context("when artifactId is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(mockClient, "https://repo1.maven.org/maven2", "org.test", "", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("artifact_id must be specified"))
			})
		})

		Context("when the server returns an error", func() {
			BeforeEach(func() {
				mockClient.err = http.ErrHandlerTimeout
				watcher = watchers.NewMavenWatcher(mockClient, "https://repo1.maven.org/maven2", "org.test", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fetching Maven metadata"))
			})
		})

		Context("when the server returns non-200 status", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 404,
					Body:       io.NopCloser(strings.NewReader("")),
				}
				watcher = watchers.NewMavenWatcher(mockClient, "https://repo1.maven.org/maven2", "org.test", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unexpected status code 404"))
			})
		})

		Context("when the XML is invalid", func() {
			BeforeEach(func() {
				mockClient.response = &http.Response{
					StatusCode: 200,
					Body:       io.NopCloser(strings.NewReader("invalid xml")),
				}
				watcher = watchers.NewMavenWatcher(mockClient, "https://repo1.maven.org/maven2", "org.test", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.Check()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("parsing XML metadata"))
			})
		})
	})

	Describe("In", func() {
		Context("with basic Maven coordinates", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(
					mockClient,
					"https://repo1.maven.org/maven2",
					"org.springframework",
					"spring-core",
					"",
					"jar",
					"",
					"",
				)
			})

			It("returns the correct artifact URL", func() {
				release, err := watcher.In("5.3.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.Ref).To(Equal("5.3.0"))
				Expect(release.URL).To(Equal("https://repo1.maven.org/maven2/org/springframework/spring-core/5.3.0/spring-core-5.3.0.jar"))
			})
		})

		Context("with classifier", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(
					mockClient,
					"https://repo1.maven.org/maven2",
					"org.springframework",
					"spring-core",
					"sources",
					"jar",
					"",
					"",
				)
			})

			It("includes classifier in filename", func() {
				release, err := watcher.In("5.3.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://repo1.maven.org/maven2/org/springframework/spring-core/5.3.0/spring-core-5.3.0-sources.jar"))
			})
		})

		Context("with custom packaging", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(
					mockClient,
					"https://repo1.maven.org/maven2",
					"org.apache.maven",
					"apache-maven",
					"",
					"zip",
					"",
					"",
				)
			})

			It("uses custom packaging extension", func() {
				release, err := watcher.In("3.8.0")
				Expect(err).NotTo(HaveOccurred())
				Expect(release.URL).To(Equal("https://repo1.maven.org/maven2/org/apache/maven/apache-maven/3.8.0/apache-maven-3.8.0.zip"))
			})
		})

		Context("when URI is missing", func() {
			BeforeEach(func() {
				watcher = watchers.NewMavenWatcher(mockClient, "", "org.test", "artifact", "", "jar", "", "")
			})

			It("returns an error", func() {
				_, err := watcher.In("1.0.0")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("uri must be specified"))
			})
		})
	})
})
