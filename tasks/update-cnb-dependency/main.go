package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/blang/semver"
	"gopkg.in/yaml.v2"
)

type BuildpackDescriptor struct {
	API       string
	Buildpack Info `toml:"buildpack"`
	Metadata  Metadata
	Order     []Order
	Stacks    []Stack
}

type Info struct {
	ID      string
	Name    string
	Version string
}

type Metadata struct {
	IncludeFiles               []string `toml:"include_files"`
	Dependencies               []Dependency
	DependencyDeprecationDates []DependencyDeprecationDate `toml:"dependency_deprecation_dates"`
}

type Dependency struct {
	ID           string
	Name         string `toml:",omitempty"`
	Sha256       string
	Source       string `toml:",omitempty"`
	SourceSha256 string `toml:"source_sha256,omitempty"`
	Stacks       []string
	URI          string
	Version      string
}

type DependencyDeprecationDate struct {
	Date        time.Time
	Link        string
	Name        string
	VersionLine string `toml:"version_line"`
	Match       string `toml:",omitempty"`
}

type Order struct {
	Group []Group
}

type Group struct {
	ID      string
	Version string
}

type Stack struct {
	ID string
}

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

type BuildMetadata struct {
	TrackerStoryID int    `json:"tracker_story_id"`
	Version        string `json:"version"`
	Source         struct {
		URL    string `json:"url"`
		Md5    string `json:"md5"`
		Sha256 string `json:"sha256"`
	} `json:"source"`
	Sha256 string `json:"sha256"`
	URL    string `json:"url"`
}

type DependencyOrchestratorConfig struct {
	DeprecatedStacks []string          `yaml:"deprecated_stacks"`
	V3Stacks         map[string]string `yaml:"v3_stacks"`
	V3DepIDs         map[string]string `yaml:"v3_dep_ids"`
	V3DepNames       map[string]string `yaml:"v3_dep_names"`
}

func main() {
	versionLine := strings.ToLower(os.Getenv("VERSION_LINE"))
	deprecationDate := os.Getenv("DEPRECATION_DATE")
	deprecationLink := os.Getenv("DEPRECATION_LINK")
	deprecationMatch := os.Getenv("DEPRECATION_MATCH")
	versionsToKeep, err := strconv.Atoi(os.Getenv("VERSIONS_TO_KEEP"))
	if err != nil {
		log.Fatal(err)
	}

	depOrchestratorConfig, buildpackDescriptor, depMetadata, buildMetadata, err := loadResources()
	if err != nil {
		log.Fatal(err)
	}

	depID := depMetadata.Source.Name
	depVersion := depMetadata.Version.Ref

	buildMetadataPaths, err := filepath.Glob(filepath.Join("builds", "binary-builds-new", depID, fmt.Sprintf("%s-*.json", depVersion)))
	if err != nil {
		log.Fatal(err)
	}

	var depsToAdd []Dependency
	for _, buildMetadataPath := range buildMetadataPaths {
		deps, err := constructDeps(depID, depVersion, buildMetadataPath, depOrchestratorConfig)
		if err != nil {
			log.Fatal(err)
		}
		depsToAdd = append(depsToAdd, deps...)
	}

	originalDeps := expandDepsForStacks(buildpackDescriptor.Metadata.Dependencies)

	updatedDeps, err := AddNewDep(originalDeps, depsToAdd)
	if err != nil {
		log.Fatal(err)
	}

	versionRange := strings.Replace(versionLine, ".x.x", ".x", 1)

	updatedDeps, err = RemoveOldDeps(updatedDeps, depID, versionRange, versionsToKeep)
	if err != nil {
		log.Fatal(err)
	}

	updatedDeprecationDates, err := UpdateDeprecationDates(
		buildpackDescriptor.Metadata.DependencyDeprecationDates,
		depID,
		versionLine,
		deprecationDate,
		deprecationLink,
		deprecationMatch,
	)
	if err != nil {
		log.Fatal(err)
	}

	buildpackDescriptor.Metadata.Dependencies = updatedDeps
	buildpackDescriptor.Metadata.DependencyDeprecationDates = updatedDeprecationDates

	buildpackTOML, err := os.OpenFile("artifacts/buildpack.toml", os.O_RDWR|os.O_CREATE, 0666)
	if err != nil {
		log.Fatal(err)
	}
	defer buildpackTOML.Close()

	if err := toml.NewEncoder(buildpackTOML).Encode(buildpackDescriptor); err != nil {
		log.Fatal(err)
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, depID, depVersion, buildMetadata.TrackerStoryID)
	if commitMessage != "" {
		output, err := exec.Command("git", "-C", "artifacts", "add", "buildpack.toml").CombinedOutput()
		if err != nil {
			log.Fatalf("%s: %s", err.Error(), string(output))
		}

		output, err = exec.Command("git", "-C", "artifacts", "commit", "-m", commitMessage).CombinedOutput()
		if err != nil {
			log.Fatalf("%s: %s", err.Error(), string(output))
		}
	}
}

func loadResources() (DependencyOrchestratorConfig, BuildpackDescriptor, DependencyMetadata, BuildMetadata, error) {
	var depOrchestratorConfig DependencyOrchestratorConfig
	if err := loadYAML(filepath.Join("config", "dependency-builds.yml"), &depOrchestratorConfig); err != nil {
		return DependencyOrchestratorConfig{}, BuildpackDescriptor{}, DependencyMetadata{}, BuildMetadata{}, err
	}

	var buildpackDescriptor BuildpackDescriptor
	if _, err := toml.DecodeFile(filepath.Join("buildpack", "buildpack.toml"), &buildpackDescriptor); err != nil {
		return DependencyOrchestratorConfig{}, BuildpackDescriptor{}, DependencyMetadata{}, BuildMetadata{}, err
	}

	var depMetadata DependencyMetadata
	if err := loadJSON(filepath.Join("source", "data.json"), &depMetadata); err != nil {
		return DependencyOrchestratorConfig{}, BuildpackDescriptor{}, DependencyMetadata{}, BuildMetadata{}, err
	}

	var buildMetadata BuildMetadata
	if err := loadJSON(filepath.Join("builds", "binary-builds-new", depMetadata.Source.Name, depMetadata.Version.Ref+".json"), &buildMetadata); err != nil {
		return DependencyOrchestratorConfig{}, BuildpackDescriptor{}, DependencyMetadata{}, BuildMetadata{}, err
	}

	return depOrchestratorConfig, buildpackDescriptor, depMetadata, buildMetadata, nil
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

func expandDepsForStacks(deps []Dependency) []Dependency {
	var expandedDeps []Dependency

	for _, dep := range deps {
		if len(dep.Stacks) == 1 {
			expandedDeps = append(expandedDeps, dep)
		} else {
			for _, stack := range dep.Stacks {
				depForStack := dep
				depForStack.Stacks = []string{stack}
				expandedDeps = append(expandedDeps, depForStack)
			}
		}
	}

	return expandedDeps
}

func constructDeps(depID, depVersion, buildMetadataPath string, depOrchestratorConfig DependencyOrchestratorConfig) ([]Dependency, error) {
	var buildMetadata BuildMetadata
	if err := loadJSON(buildMetadataPath, &buildMetadata); err != nil {
		return nil, err
	}

	stacks, err := determineStacks(buildMetadataPath, depOrchestratorConfig.V3Stacks, depOrchestratorConfig.DeprecatedStacks)
	if err != nil {
		return nil, err
	}

	var deps []Dependency
	for _, stack := range stacks {
		deps = append(deps, Dependency{
			ID:           depID,
			Name:         depOrchestratorConfig.V3DepNames[depID],
			Sha256:       buildMetadata.Sha256,
			Source:       buildMetadata.Source.URL,
			SourceSha256: buildMetadata.Source.Sha256,
			Stacks:       []string{stack},
			URI:          buildMetadata.URL,
			Version:      depVersion,
		})
	}
	return deps, nil
}

func determineStacks(buildMetadataPath string, stacksMap map[string]string, deprecatedStacks []string) ([]string, error) {
	var stacks []string
	if strings.HasSuffix(buildMetadataPath, "any-stack.json") {
		for _, stackID := range stacksMap {
			stacks = append(stacks, stackID)
		}
		if len(stacks) == 0 {
			return nil, errors.New("stack is 'any-stack' but no stacks are configured, check dependency-builds.yml")
		}
	} else {
		stackRegexp := regexp.MustCompile(`-([^-]*)\.json$`)
		matches := stackRegexp.FindStringSubmatch(buildMetadataPath)
		if len(matches) != 2 {
			return nil, fmt.Errorf("expected to find one stack name in filename (%s) but found: %v", filepath.Base(buildMetadataPath), matches[1:])
		}
		stack := matches[1]

		for _, deprecatedStack := range deprecatedStacks {
			if stack == deprecatedStack {
				return nil, nil
			}
		}

		for stackName, stackID := range stacksMap {
			if stack == stackName {
				stacks = []string{stackID}
				break
			}
		}
		if len(stacks) == 0 {
			return nil, fmt.Errorf("%s is not a valid stack", stack)
		}
	}

	return stacks, nil
}

func sortDeps(deps []Dependency) func(i, j int) bool {
	return func(i, j int) bool {
		if deps[i].ID != deps[j].ID {
			return deps[i].ID < deps[j].ID
		}

		firstVersion := semver.MustParse(deps[i].Version)
		secondVersion := semver.MustParse(deps[j].Version)

		if firstVersion.EQ(secondVersion) {
			return deps[i].Stacks[0] < deps[j].Stacks[0]
		}

		return firstVersion.LT(secondVersion)
	}
}
