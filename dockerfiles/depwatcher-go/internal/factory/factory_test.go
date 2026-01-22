package factory_test

import (
	"encoding/json"
	"os"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/internal/factory"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

func TestFactory(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Factory Suite")
}

var _ = Describe("Factory", func() {
	Describe("Check", func() {
		Context("with valid source types", func() {
			PIt("routes github_releases to GithubReleasesWatcher", func() {
				source := factory.Source{
					Type: "github_releases",
					Repo: "cloudfoundry/hwc",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes github_tags to GithubTagsWatcher", func() {
				source := factory.Source{
					Type:     "github_tags",
					Repo:     "ruby/ruby",
					TagRegex: `^v[\d_]+$`,
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes ruby to RubyWatcher", func() {
				source := factory.Source{
					Type: "ruby",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes php to PHPWatcher", func() {
				source := factory.Source{
					Type: "php",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes python to PythonWatcher", func() {
				source := factory.Source{
					Type: "python",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes go to GoWatcher", func() {
				source := factory.Source{
					Type: "go",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes node to NodeWatcher", func() {
				source := factory.Source{
					Type: "node",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes npm to NPMWatcher", func() {
				source := factory.Source{
					Type: "npm",
					Name: "typescript",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes jruby to JRubyWatcher", func() {
				source := factory.Source{
					Type: "jruby",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes nginx to NginxWatcher", func() {
				source := factory.Source{
					Type: "nginx",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes httpd to HttpdWatcher", func() {
				source := factory.Source{
					Type: "httpd",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes pypi to PyPIWatcher", func() {
				source := factory.Source{
					Type: "pypi",
					Name: "requests",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes rubygems to RubygemsWatcher", func() {
				source := factory.Source{
					Type: "rubygems",
					Name: "rake",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes rubygems_cli to RubygemsCLIWatcher", func() {
				source := factory.Source{
					Type: "rubygems_cli",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes openresty to OpenrestyWatcher", func() {
				source := factory.Source{
					Type: "openresty",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes icu to ICUWatcher", func() {
				source := factory.Source{
					Type: "icu",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes miniconda to MinicondaWatcher", func() {
				source := factory.Source{
					Type:          "miniconda",
					PythonVersion: "3.9",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes r to RWatcher", func() {
				source := factory.Source{
					Type: "r",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-sdk to DotnetSDKWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-sdk",
					VersionFilter: "8.0",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-runtime to DotnetRuntimeWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-runtime",
					VersionFilter: "8.0",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-aspnetcore to DotnetAspnetcoreWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-aspnetcore",
					VersionFilter: "8.0",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes rserve to CRANWatcher", func() {
				source := factory.Source{
					Type: "rserve",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes forecast to CRANWatcher", func() {
				source := factory.Source{
					Type: "forecast",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes plumber to CRANWatcher", func() {
				source := factory.Source{
					Type: "plumber",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes shiny to CRANWatcher", func() {
				source := factory.Source{
					Type: "shiny",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes ca_apm_agent to CaApmAgentWatcher", func() {
				source := factory.Source{
					Type: "ca_apm_agent",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes appd_agent to AppdAgentWatcher", func() {
				source := factory.Source{
					Type: "appd_agent",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("with unknown source type", func() {
			It("returns an error", func() {
				source := factory.Source{
					Type: "unknown_type",
				}

				_, err := factory.Check(source, nil)
				Expect(err).To(MatchError("unknown type: unknown_type"))
			})
		})

		Context("with version filtering", func() {
			PIt("filters versions using semver pattern", func() {
				source := factory.Source{
					Type:          "ruby",
					VersionFilter: "3.2.X",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			It("skips filtering for node-lts", func() {
				source := factory.Source{
					Type:          "node",
					VersionFilter: "node-lts",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("with current version filtering", func() {
			PIt("filters out versions less than current", func() {
				source := factory.Source{
					Type: "ruby",
				}
				currentVersion := &base.Internal{
					Ref: "3.2.0",
				}

				_, err := factory.Check(source, currentVersion)
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("with github_releases options", func() {
			PIt("applies extension filter", func() {
				source := factory.Source{
					Type:      "github_releases",
					Repo:      "cloudfoundry/hwc",
					Extension: ".exe",
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("applies fetch_source option", func() {
				source := factory.Source{
					Type:        "github_releases",
					Repo:        "cloudfoundry/hwc",
					FetchSource: true,
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("applies prerelease option", func() {
				source := factory.Source{
					Type:       "github_releases",
					Repo:       "cloudfoundry/hwc",
					Prerelease: true,
				}

				_, err := factory.Check(source, nil)
				Expect(err).ToNot(HaveOccurred())
			})
		})
	})

	Describe("In", func() {
		Context("with valid source types", func() {
			PIt("routes github_releases to GithubReleasesWatcher", func() {
				source := factory.Source{
					Type: "github_releases",
					Repo: "cloudfoundry/hwc",
				}
				version := base.Internal{Ref: "1.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes github_tags to GithubTagsWatcher", func() {
				source := factory.Source{
					Type:     "github_tags",
					Repo:     "ruby/ruby",
					TagRegex: `^v[\d_]+$`,
				}
				version := base.Internal{Ref: "3.2.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes ruby to RubyWatcher", func() {
				source := factory.Source{
					Type: "ruby",
				}
				version := base.Internal{Ref: "3.2.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes php to PHPWatcher", func() {
				source := factory.Source{
					Type: "php",
				}
				version := base.Internal{Ref: "8.2.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes python to PythonWatcher", func() {
				source := factory.Source{
					Type: "python",
				}
				version := base.Internal{Ref: "3.11.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes go to GoWatcher", func() {
				source := factory.Source{
					Type: "go",
				}
				version := base.Internal{Ref: "1.21.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			It("routes node to NodeWatcher", func() {
				source := factory.Source{
					Type: "node",
				}
				version := base.Internal{Ref: "18.12.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes npm to NPMWatcher", func() {
				source := factory.Source{
					Type: "npm",
					Name: "typescript",
				}
				version := base.Internal{Ref: "4.9.5"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes jruby to JRubyWatcher", func() {
				source := factory.Source{
					Type: "jruby",
				}
				version := base.Internal{Ref: "9.4.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes nginx to NginxWatcher", func() {
				source := factory.Source{
					Type: "nginx",
				}
				version := base.Internal{Ref: "1.25.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes httpd to HttpdWatcher", func() {
				source := factory.Source{
					Type: "httpd",
				}
				version := base.Internal{Ref: "2.4.59"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes pypi to PyPIWatcher", func() {
				source := factory.Source{
					Type: "pypi",
					Name: "requests",
				}
				version := base.Internal{Ref: "2.28.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes rubygems to RubygemsWatcher", func() {
				source := factory.Source{
					Type: "rubygems",
					Name: "rake",
				}
				version := base.Internal{Ref: "13.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes rubygems_cli to RubygemsCLIWatcher", func() {
				source := factory.Source{
					Type: "rubygems_cli",
				}
				version := base.Internal{Ref: "3.4.10"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes openresty to OpenrestyWatcher", func() {
				source := factory.Source{
					Type: "openresty",
				}
				version := base.Internal{Ref: "1.19.3.1"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes icu to ICUWatcher", func() {
				source := factory.Source{
					Type: "icu",
				}
				version := base.Internal{Ref: "65.1.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes miniconda to MinicondaWatcher", func() {
				source := factory.Source{
					Type:          "miniconda",
					PythonVersion: "3.9",
				}
				version := base.Internal{Ref: "23.1.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes r to RWatcher", func() {
				source := factory.Source{
					Type: "r",
				}
				version := base.Internal{Ref: "4.0.3"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-sdk to DotnetSDKWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-sdk",
					VersionFilter: "8.0",
				}
				version := base.Internal{Ref: "8.0.100"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-runtime to DotnetRuntimeWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-runtime",
					VersionFilter: "8.0",
				}
				version := base.Internal{Ref: "8.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes dotnet-aspnetcore to DotnetAspnetcoreWatcher", func() {
				source := factory.Source{
					Type:          "dotnet-aspnetcore",
					VersionFilter: "8.0",
				}
				version := base.Internal{Ref: "8.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes rserve to CRANWatcher", func() {
				source := factory.Source{
					Type: "rserve",
				}
				version := base.Internal{Ref: "1.7.3"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes forecast to CRANWatcher", func() {
				source := factory.Source{
					Type: "forecast",
				}
				version := base.Internal{Ref: "8.4"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes plumber to CRANWatcher", func() {
				source := factory.Source{
					Type: "plumber",
				}
				version := base.Internal{Ref: "0.4.6"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes shiny to CRANWatcher", func() {
				source := factory.Source{
					Type: "shiny",
				}
				version := base.Internal{Ref: "1.2.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes ca_apm_agent to CaApmAgentWatcher", func() {
				source := factory.Source{
					Type: "ca_apm_agent",
				}
				version := base.Internal{Ref: "10.6.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("routes appd_agent to AppdAgentWatcher", func() {
				source := factory.Source{
					Type: "appd_agent",
				}
				version := base.Internal{Ref: "3.1.1-14"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("with unknown source type", func() {
			It("returns an error", func() {
				source := factory.Source{
					Type: "unknown_type",
				}
				version := base.Internal{Ref: "1.0.0"}

				_, err := factory.In(source, version)
				Expect(err).To(MatchError("unknown type: unknown_type"))
			})
		})

		Context("with github_releases options", func() {
			PIt("applies extension filter", func() {
				source := factory.Source{
					Type:      "github_releases",
					Repo:      "cloudfoundry/hwc",
					Extension: ".exe",
				}
				version := base.Internal{Ref: "1.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})

			PIt("applies fetch_source option", func() {
				source := factory.Source{
					Type:        "github_releases",
					Repo:        "cloudfoundry/hwc",
					FetchSource: true,
				}
				version := base.Internal{Ref: "1.0.0"}

				_, err := factory.In(source, version)
				Expect(err).ToNot(HaveOccurred())
			})
		})
	})

	Describe("SetupGithubToken", func() {
		AfterEach(func() {
			os.Unsetenv("OAUTH_AUTHORIZATION_TOKEN")
		})

		It("sets environment variable from source.GithubToken", func() {
			source := factory.Source{
				Type:        "github_releases",
				Repo:        "cloudfoundry/hwc",
				GithubToken: "test_token_12345",
			}

			factory.SetupGithubToken(&source)

			Expect(os.Getenv("OAUTH_AUTHORIZATION_TOKEN")).To(Equal("test_token_12345"))
		})

		It("clears source.GithubToken after setting env var", func() {
			source := factory.Source{
				Type:        "github_releases",
				Repo:        "cloudfoundry/hwc",
				GithubToken: "test_token_12345",
			}

			factory.SetupGithubToken(&source)

			Expect(source.GithubToken).To(Equal(""))
		})

		It("does nothing when GithubToken is empty", func() {
			source := factory.Source{
				Type: "github_releases",
				Repo: "cloudfoundry/hwc",
			}

			factory.SetupGithubToken(&source)

			Expect(os.Getenv("OAUTH_AUTHORIZATION_TOKEN")).To(Equal(""))
		})
	})

	Describe("ParseCheckRequest", func() {
		It("parses valid JSON into CheckRequest", func() {
			jsonData := `{
				"source": {
					"type": "ruby",
					"version_filter": "3.2.X"
				},
				"version": {
					"ref": "3.2.0"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Source.VersionFilter).To(Equal("3.2.X"))
			Expect(req.Version).NotTo(BeNil())
			Expect(req.Version.Ref).To(Equal("3.2.0"))
		})

		It("handles missing version field", func() {
			jsonData := `{
				"source": {
					"type": "ruby"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Version).To(BeNil())
		})

		It("returns error for invalid JSON", func() {
			jsonData := `{invalid json}`

			_, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("parsing check request"))
		})

		It("parses github_releases with all options", func() {
			jsonData := `{
				"source": {
					"type": "github_releases",
					"repo": "cloudfoundry/hwc",
					"extension": ".exe",
					"prerelease": true,
					"fetch_source": true,
					"version_filter": "1.0.X",
					"github_token": "ghp_token"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_releases"))
			Expect(req.Source.Repo).To(Equal("cloudfoundry/hwc"))
			Expect(req.Source.Extension).To(Equal(".exe"))
			Expect(req.Source.Prerelease).To(BeTrue())
			Expect(req.Source.FetchSource).To(BeTrue())
			Expect(req.Source.VersionFilter).To(Equal("1.0.X"))
			Expect(req.Source.GithubToken).To(Equal("ghp_token"))
		})

		It("parses github_tags with tag_regex", func() {
			jsonData := `{
				"source": {
					"type": "github_tags",
					"repo": "ruby/ruby",
					"tag_regex": "^v[\\d_]+$"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_tags"))
			Expect(req.Source.Repo).To(Equal("ruby/ruby"))
			Expect(req.Source.TagRegex).To(Equal(`^v[\d_]+$`))
		})

		It("parses npm with name field", func() {
			jsonData := `{
				"source": {
					"type": "npm",
					"name": "typescript"
				}
			}`

			req, err := factory.ParseCheckRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("npm"))
			Expect(req.Source.Name).To(Equal("typescript"))
		})
	})

	Describe("ParseInRequest", func() {
		It("parses valid JSON into InRequest", func() {
			jsonData := `{
				"source": {
					"type": "ruby",
					"version_filter": "3.2.X"
				},
				"version": {
					"ref": "3.2.0"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("ruby"))
			Expect(req.Source.VersionFilter).To(Equal("3.2.X"))
			Expect(req.Version.Ref).To(Equal("3.2.0"))
		})

		It("returns error for invalid JSON", func() {
			jsonData := `{invalid json}`

			_, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("parsing in request"))
		})

		It("parses github_releases with all options", func() {
			jsonData := `{
				"source": {
					"type": "github_releases",
					"repo": "cloudfoundry/hwc",
					"extension": ".exe",
					"fetch_source": true
				},
				"version": {
					"ref": "1.0.0"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			Expect(err).NotTo(HaveOccurred())
			Expect(req.Source.Type).To(Equal("github_releases"))
			Expect(req.Source.Repo).To(Equal("cloudfoundry/hwc"))
			Expect(req.Source.Extension).To(Equal(".exe"))
			Expect(req.Source.FetchSource).To(BeTrue())
			Expect(req.Version.Ref).To(Equal("1.0.0"))
		})

		It("requires version field", func() {
			jsonData := `{
				"source": {
					"type": "ruby"
				}
			}`

			req, err := factory.ParseInRequest([]byte(jsonData))

			// JSON parsing succeeds, but version.ref will be empty
			Expect(err).NotTo(HaveOccurred())
			Expect(req.Version.Ref).To(Equal(""))
		})
	})

	Describe("CheckResponse marshaling", func() {
		It("marshals to JSON array", func() {
			response := factory.CheckResponse{
				base.Internal{Ref: "3.2.0"},
				base.Internal{Ref: "3.2.1"},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`[
				{"ref": "3.2.0"},
				{"ref": "3.2.1"}
			]`))
		})

		It("marshals empty response", func() {
			response := factory.CheckResponse{}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`[]`))
		})
	})

	Describe("InResponse marshaling", func() {
		It("marshals version and metadata", func() {
			response := factory.InResponse{
				Version: base.Internal{Ref: "3.2.0"},
				Metadata: []factory.MetadataField{
					{Name: "url", Value: "https://example.com"},
					{Name: "sha256", Value: "abc123"},
				},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`{
				"version": {"ref": "3.2.0"},
				"metadata": [
					{"name": "url", "value": "https://example.com"},
					{"name": "sha256", "value": "abc123"}
				]
			}`))
		})

		It("handles nil metadata", func() {
			response := factory.InResponse{
				Version: base.Internal{Ref: "3.2.0"},
			}

			jsonData, err := json.Marshal(response)

			Expect(err).NotTo(HaveOccurred())
			Expect(string(jsonData)).To(MatchJSON(`{
				"version": {"ref": "3.2.0"}
			}`))
		})
	})
})
