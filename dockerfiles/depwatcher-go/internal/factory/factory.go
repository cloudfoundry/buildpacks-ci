package factory

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
)

type Source struct {
	Type          string `json:"type"`
	Repo          string `json:"repo,omitempty"`
	Name          string `json:"name,omitempty"`
	TagRegex      string `json:"tag_regex,omitempty"`
	Extension     string `json:"extension,omitempty"`
	Prerelease    bool   `json:"prerelease,omitempty"`
	FetchSource   bool   `json:"fetch_source,omitempty"`
	VersionFilter string `json:"version_filter,omitempty"`
	GithubToken   string `json:"github_token,omitempty"`
	PythonVersion string `json:"python_version,omitempty"`
}

type CheckRequest struct {
	Source  Source         `json:"source"`
	Version *base.Internal `json:"version,omitempty"`
}

type CheckResponse []base.Internal

type InRequest struct {
	Source  Source        `json:"source"`
	Version base.Internal `json:"version"`
}

type InResponse struct {
	Version  interface{}     `json:"version"`
	Metadata []MetadataField `json:"metadata,omitempty"`
}

type MetadataField struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

func SetupGithubToken(source *Source) {
	if source.GithubToken != "" {
		os.Setenv("OAUTH_AUTHORIZATION_TOKEN", source.GithubToken)
		source.GithubToken = ""
	}
}

func Check(source Source, currentVersion *base.Internal) ([]base.Internal, error) {
	client := base.NewHTTPClient(false)

	var versions []base.Internal
	var err error

	switch source.Type {
	case "github_releases":
		watcher := watchers.NewGithubReleasesWatcher(client, source.Repo, source.Prerelease)
		if source.Extension != "" {
			watcher = watcher.WithExtension(source.Extension)
		}
		if source.FetchSource {
			watcher = watcher.WithFetchSource(true)
		}
		versions, err = watcher.Check()

	case "github_tags":
		watcher := watchers.NewGithubTagsWatcher(client, source.Repo)
		versions, err = watcher.Check(source.TagRegex)

	case "ruby":
		watcher := watchers.NewRubyWatcher(client)
		versions, err = watcher.Check()

	case "php":
		watcher := watchers.NewPHPWatcher(client)
		versions, err = watcher.Check(source.VersionFilter)

	case "python":
		watcher := watchers.NewPythonWatcher(client)
		versions, err = watcher.Check()

	case "go":
		watcher := watchers.NewGoWatcher(client)
		versions, err = watcher.Check()

	case "node":
		if source.VersionFilter == "node-lts" {
			watcher := watchers.NewNodeLTSWatcher(client)
			versions, err = watcher.Check()
		} else {
			watcher := watchers.NewNodeWatcher(client)
			versions, err = watcher.Check()
		}

	case "npm":
		watcher := watchers.NewNPMWatcher(client)
		versions, err = watcher.Check(source.Name)

	case "jruby":
		watcher := watchers.NewJRubyWatcher(client)
		versions, err = watcher.Check()

	case "nginx":
		watcher := watchers.NewNginxWatcher(client)
		versions, err = watcher.Check()

	case "httpd":
		watcher := watchers.NewHttpdWatcher(client)
		versions, err = watcher.Check()

	case "pypi":
		watcher := watchers.NewPyPIWatcher(client)
		versions, err = watcher.Check(source.Name)

	case "rubygems":
		watcher := watchers.NewRubygemsWatcher(client, source.Name)
		versions, err = watcher.Check()

	case "rubygems_cli":
		watcher := watchers.NewRubygemsCLIWatcher(client)
		versions, err = watcher.Check()

	case "openresty":
		watcher := watchers.NewOpenrestyWatcher(client)
		versions, err = watcher.Check()

	case "icu":
		watcher := watchers.NewICUWatcher(client)
		versions, err = watcher.Check()

	case "miniconda":
		watcher := watchers.NewMinicondaWatcher(client, source.PythonVersion)
		versions, err = watcher.Check()

	case "r":
		watcher := watchers.NewRWatcher(client)
		versions, err = watcher.Check()

	case "dotnet-sdk":
		watcher := watchers.NewDotnetSDKWatcher(client)
		versions, err = watcher.Check(source.VersionFilter)

	case "dotnet-runtime":
		watcher := watchers.NewDotnetRuntimeWatcher(client)
		versions, err = watcher.Check(source.VersionFilter)

	case "dotnet-aspnetcore":
		watcher := watchers.NewDotnetAspnetcoreWatcher(client)
		versions, err = watcher.Check(source.VersionFilter)

	case "rserve":
		watcher := watchers.NewCRANWatcher(client, "Rserve")
		versions, err = watcher.Check()

	case "forecast":
		watcher := watchers.NewCRANWatcher(client, "forecast")
		versions, err = watcher.Check()

	case "plumber":
		watcher := watchers.NewCRANWatcher(client, "plumber")
		versions, err = watcher.Check()

	case "shiny":
		watcher := watchers.NewCRANWatcher(client, "shiny")
		versions, err = watcher.Check()

	case "ca_apm_agent":
		watcher := watchers.NewCaApmAgentWatcher(client)
		versions, err = watcher.Check()

	case "appd_agent":
		watcher := watchers.NewAppdAgentWatcher(client)
		versions, err = watcher.Check()

	default:
		return nil, fmt.Errorf("unknown type: %s", source.Type)
	}

	if err != nil {
		return nil, err
	}

	if source.VersionFilter != "" && source.VersionFilter != "node-lts" {
		filtered, err := filterVersions(versions, source.VersionFilter)
		if err != nil {
			return nil, err
		}
		versions = filtered
	}

	if currentVersion != nil {
		current, err := semver.Parse(currentVersion.Ref)
		if err == nil {
			var filtered []base.Internal
			for _, v := range versions {
				vSemver, err := semver.Parse(v.Ref)
				if err != nil {
					filtered = append(filtered, v)
					continue
				}
				if !vSemver.LessThan(current) {
					filtered = append(filtered, v)
				}
			}
			versions = filtered
		}
	}

	return versions, nil
}

func In(source Source, version base.Internal) (interface{}, error) {
	client := base.NewHTTPClient(false)

	switch source.Type {
	case "github_releases":
		watcher := watchers.NewGithubReleasesWatcher(client, source.Repo, source.Prerelease)
		if source.Extension != "" {
			watcher = watcher.WithExtension(source.Extension)
		}
		if source.FetchSource {
			watcher = watcher.WithFetchSource(true)
		}
		return watcher.In(version.Ref)

	case "github_tags":
		watcher := watchers.NewGithubTagsWatcher(client, source.Repo)
		return watcher.In(version.Ref)

	case "ruby":
		watcher := watchers.NewRubyWatcher(client)
		return watcher.In(version.Ref)

	case "php":
		watcher := watchers.NewPHPWatcher(client)
		return watcher.In(version.Ref)

	case "python":
		watcher := watchers.NewPythonWatcher(client)
		return watcher.In(version.Ref)

	case "go":
		watcher := watchers.NewGoWatcher(client)
		return watcher.In(version.Ref)

	case "node":
		watcher := watchers.NewNodeWatcher(client)
		return watcher.In(version.Ref)

	case "npm":
		watcher := watchers.NewNPMWatcher(client)
		return watcher.In(source.Name, version.Ref)

	case "jruby":
		watcher := watchers.NewJRubyWatcher(client)
		return watcher.In(version.Ref)

	case "nginx":
		watcher := watchers.NewNginxWatcher(client)
		return watcher.In(version.Ref)

	case "httpd":
		watcher := watchers.NewHttpdWatcher(client)
		return watcher.In(version.Ref)

	case "pypi":
		watcher := watchers.NewPyPIWatcher(client)
		return watcher.In(source.Name, version.Ref)

	case "rubygems":
		watcher := watchers.NewRubygemsWatcher(client, source.Name)
		return watcher.In(version.Ref)

	case "rubygems_cli":
		watcher := watchers.NewRubygemsCLIWatcher(client)
		return watcher.In(version.Ref)

	case "openresty":
		watcher := watchers.NewOpenrestyWatcher(client)
		return watcher.In(version.Ref)

	case "icu":
		watcher := watchers.NewICUWatcher(client)
		return watcher.In(version.Ref)

	case "miniconda":
		watcher := watchers.NewMinicondaWatcher(client, source.PythonVersion)
		return watcher.In(version.Ref)

	case "r":
		watcher := watchers.NewRWatcher(client)
		return watcher.In(version.Ref)

	case "dotnet-sdk":
		watcher := watchers.NewDotnetSDKWatcher(client)
		return watcher.In(version.Ref)

	case "dotnet-runtime":
		watcher := watchers.NewDotnetRuntimeWatcher(client)
		return watcher.In(version.Ref)

	case "dotnet-aspnetcore":
		watcher := watchers.NewDotnetAspnetcoreWatcher(client)
		return watcher.In(version.Ref)

	case "rserve":
		watcher := watchers.NewCRANWatcher(client, "Rserve")
		return watcher.In(version.Ref)

	case "forecast":
		watcher := watchers.NewCRANWatcher(client, "forecast")
		return watcher.In(version.Ref)

	case "plumber":
		watcher := watchers.NewCRANWatcher(client, "plumber")
		return watcher.In(version.Ref)

	case "shiny":
		watcher := watchers.NewCRANWatcher(client, "shiny")
		return watcher.In(version.Ref)

	case "ca_apm_agent":
		watcher := watchers.NewCaApmAgentWatcher(client)
		return watcher.In(version.Ref)

	case "appd_agent":
		watcher := watchers.NewAppdAgentWatcher(client)
		return watcher.In(version.Ref)

	default:
		return nil, fmt.Errorf("unknown type: %s", source.Type)
	}
}

func filterVersions(versions []base.Internal, pattern string) ([]base.Internal, error) {
	filter := semver.NewFilter(pattern)

	var filtered []base.Internal
	for _, v := range versions {
		version, err := semver.Parse(v.Ref)
		if err != nil {
			continue
		}
		if filter.Match(version) {
			filtered = append(filtered, v)
		}
	}

	return filtered, nil
}

func ParseCheckRequest(data []byte) (CheckRequest, error) {
	var req CheckRequest
	if err := json.Unmarshal(data, &req); err != nil {
		return CheckRequest{}, fmt.Errorf("parsing check request: %w", err)
	}
	return req, nil
}

func ParseInRequest(data []byte) (InRequest, error) {
	var req InRequest
	if err := json.Unmarshal(data, &req); err != nil {
		return InRequest{}, fmt.Errorf("parsing in request: %w", err)
	}
	return req, nil
}
