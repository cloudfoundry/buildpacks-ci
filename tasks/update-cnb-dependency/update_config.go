package main

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/pkg/errors"

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

type EnvVars struct {
	DeprecationDate DependencyDeprecationDate
	VersionLine     string
	VersionsToKeep  int
}

type UpdateConfig struct {
	Envs          EnvVars
	Orchestrator  DependencyOrchestratorConfig
	BuildMetadata BuildMetadata
	Dep           Dependency
	BuildpackTOML BuildpackTOML
}

func NewUpdateConfig() (UpdateConfig, error) {
	var depOrchestratorConfig DependencyOrchestratorConfig
	if err := loadYAML(filepath.Join("config", "dependency-builds.yml"), &depOrchestratorConfig); err != nil {
		return UpdateConfig{}, err
	}

	var buildpackTOML BuildpackTOML
	if _, err := toml.DecodeFile(filepath.Join("buildpack", "buildpack.toml"), &buildpackTOML); err != nil {
		return UpdateConfig{}, err
	}

	var depMetadata DependencyMetadata
	if err := loadJSON(filepath.Join("source", "data.json"), &depMetadata); err != nil {
		return UpdateConfig{}, err
	}
	dep := Dependency{
		ID:      depMetadata.Source.Name,
		Version: depMetadata.Version.Ref,
	}

	envVars, err := loadEnvVariables(dep.ID)
	if err != nil {
		return UpdateConfig{}, err
	}

	var buildMetadata BuildMetadata
	if err := loadJSON(filepath.Join("builds", "binary-builds-new", depMetadata.Source.Name, depMetadata.Version.Ref+".json"), &buildMetadata); err != nil {
		return UpdateConfig{}, err
	}

	return UpdateConfig{
		Envs:          envVars,
		Orchestrator:  depOrchestratorConfig,
		BuildMetadata: buildMetadata,
		Dep:           dep,
		BuildpackTOML: buildpackTOML,
	}, nil
}

func loadEnvVariables(dependencyDeprecationDateName string) (EnvVars, error) {
	envVars := EnvVars{}
	var err error
	deprecationDate := os.Getenv("DEPRECATION_DATE")
	deprecationLink := os.Getenv("DEPRECATION_LINK")
	deprecationMatch := os.Getenv("DEPRECATION_MATCH")
	envVars.VersionLine = strings.ToLower(os.Getenv("VERSION_LINE"))
	envVars.DeprecationDate, err = NewDependencyDeprecationDate(deprecationDate, deprecationLink, dependencyDeprecationDateName, envVars.VersionLine, deprecationMatch)
	if err != nil {
		return EnvVars{}, errors.Wrap(err, "failed to initialize dependency deprecation date")
	}

	envVars.VersionsToKeep, err = strconv.Atoi(os.Getenv("VERSIONS_TO_KEEP"))
	return envVars, err
}

func loadJSON(path string, out interface{}) error {
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(contents, out)
}

func loadYAML(path string, out interface{}) error {
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	return yaml.Unmarshal(contents, out)
}
