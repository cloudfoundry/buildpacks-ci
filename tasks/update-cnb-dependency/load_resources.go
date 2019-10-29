package main

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"

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
		Sha256 string `json:"sha256"`
	} `json:"version"`
}

func loadResources() (EnvVars, DependencyOrchestratorConfig, BuildpackToml, Dependency, BuildMetadata, error) {
	envVars, err := loadEnvVariables()
	if err != nil {
		return EnvVars{}, DependencyOrchestratorConfig{}, BuildpackToml{}, Dependency{}, BuildMetadata{}, err
	}

	var depOrchestratorConfig DependencyOrchestratorConfig
	if err := loadYAML(filepath.Join("config", "dependency-builds.yml"), &depOrchestratorConfig); err != nil {
		return EnvVars{}, DependencyOrchestratorConfig{}, BuildpackToml{}, Dependency{}, BuildMetadata{}, err
	}

	var buildpackDescriptor BuildpackToml
	if _, err := toml.DecodeFile(filepath.Join("buildpack", "buildpack.toml"), &buildpackDescriptor); err != nil {
		return EnvVars{}, DependencyOrchestratorConfig{}, BuildpackToml{}, Dependency{}, BuildMetadata{}, err
	}

	var depMetadata DependencyMetadata
	if err := loadJSON(filepath.Join("source", "data.json"), &depMetadata); err != nil {
		return EnvVars{}, DependencyOrchestratorConfig{}, BuildpackToml{}, Dependency{}, BuildMetadata{}, err
	}
	dep := Dependency{
		ID:      depMetadata.Source.Name,
		Version: depMetadata.Version.Ref,
	}

	var buildMetadata BuildMetadata
	if err := loadJSON(filepath.Join("builds", "binary-builds-new", depMetadata.Source.Name, depMetadata.Version.Ref+".json"), &buildMetadata); err != nil {
		return EnvVars{}, DependencyOrchestratorConfig{}, BuildpackToml{}, Dependency{}, BuildMetadata{}, err
	}

	return envVars, depOrchestratorConfig, buildpackDescriptor, dep, buildMetadata, nil
}

func loadEnvVariables() (EnvVars, error) {
	envVars := EnvVars{}
	var err error
	envVars.DeprecationDate = os.Getenv("DEPRECATION_DATE")
	envVars.DeprecationLink = os.Getenv("DEPRECATION_LINK")
	envVars.DeprecationMatch = os.Getenv("DEPRECATION_MATCH")
	envVars.VersionLine = strings.ToLower(os.Getenv("VERSION_LINE"))
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
