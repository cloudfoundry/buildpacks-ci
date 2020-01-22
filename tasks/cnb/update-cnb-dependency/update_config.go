package main

import (
	"encoding/json"
	"io/ioutil"
	"path/filepath"

	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"

	"gopkg.in/yaml.v2"

	"github.com/BurntSushi/toml"
)

type DependencyMetadata struct {
	Source struct {
		Name          string `json:"name"`
		Type          string `json:"type"`
		VersionFilter string `json:"version_filter"`
	} `json:"source"`
	Version struct {
		Ref    string `json:"ref"`
		URL    string `json:"url"`
		SHA256 string `json:"sha256"`
	} `json:"version"`
}

type BuildMetadata struct {
	TrackerStoryID int    `json:"tracker_story_id"`
	Version        string `json:"version"`
	Source         struct {
		URL    string `json:"url"`
		Md5    string `json:"md5"`
		SHA256 string `json:"sha256"`
	} `json:"source"`
	SHA256 string `json:"sha256"`
	URL    string `json:"url"`
}

type DependencyOrchestratorConfig struct {
	DeprecatedStacks []string          `yaml:"deprecated_stacks"`
	V3Stacks         map[string]string `yaml:"v3_stacks"`
	V3DepIDs         map[string]string `yaml:"v3_dep_ids"`
	V3DepNames       map[string]string `yaml:"v3_dep_names"`
	IncludeTiny      []string          `yaml:"include_tiny_in_any_stack"`
}

type UpdateConfig struct {
	Orchestrator  DependencyOrchestratorConfig
	BuildMetadata BuildMetadata
	Dep           Dependency
	BuildpackTOML helpers.BuildpackTOML
}

func NewUpdateConfig(dependencyBuildsConfig, buildpackTOMLContents, sourceData, binaryBuildsPath string) (UpdateConfig, error) {
	var depOrchestratorConfig DependencyOrchestratorConfig
	if err := yaml.Unmarshal([]byte(dependencyBuildsConfig), &depOrchestratorConfig); err != nil {
		return UpdateConfig{}, err
	}

	var buildpackTOML helpers.BuildpackTOML
	if _, err := toml.Decode(buildpackTOMLContents, &buildpackTOML); err != nil {
		return UpdateConfig{}, err
	}

	var depMetadata DependencyMetadata
	if err := json.Unmarshal([]byte(sourceData), &depMetadata); err != nil {
		return UpdateConfig{}, err
	}
	dep := Dependency{
		ID:      depMetadata.Source.Name,
		Version: depMetadata.Version.Ref,
	}

	buildMetadataContents, err := ioutil.ReadFile(filepath.Join(binaryBuildsPath, depMetadata.Source.Name, depMetadata.Version.Ref+".json"))
	if err != nil {
		return UpdateConfig{}, err
	}

	var buildMetadata BuildMetadata
	if err := json.Unmarshal(buildMetadataContents, &buildMetadata); err != nil {
		return UpdateConfig{}, err
	}

	return UpdateConfig{
		Orchestrator:  depOrchestratorConfig,
		BuildMetadata: buildMetadata,
		Dep:           dep,
		BuildpackTOML: buildpackTOML,
	}, nil
}
