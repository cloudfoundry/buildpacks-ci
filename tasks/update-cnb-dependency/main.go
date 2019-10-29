package main

import (
	"errors"
	"fmt"
	"log"
	"path/filepath"
	"regexp"
	"strings"
)

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

type EnvVars struct {
	DeprecationDate  string
	DeprecationLink  string
	DeprecationMatch string
	VersionLine      string
	VersionsToKeep   int
}

func main() {
	// TODO: Should we use a struct to wrap all of these?
	envs, depOrchestratorConfig, buildpackToml, dep, buildMetadata, err := loadResources()
	if err != nil {
		log.Fatalf("Failed to load task resources: %s", err)
	}

	depsToAdd, err := loadAndConstructBinaryBuildsDependencyListForDep(dep, depOrchestratorConfig)
	if err != nil {
		log.Fatalf("Failed to construct list of dependencies to add: %s", err)
	}

	originalDeps := expandDependenciesForEachStack(buildpackToml.Metadata.Dependencies)

	updatedDeps, err := MergeDependencyLists(originalDeps, depsToAdd)
	if err != nil {
		log.Fatal(err)
	}

	updatedDeps, err = RemoveOldDeps(updatedDeps, dep.ID,
		envs.VersionLine, envs.VersionsToKeep)
	if err != nil {
		log.Fatal(err)
	}

	updatedDeprecationDates, err := UpdateDeprecationDates(
		buildpackToml.Metadata.DependencyDeprecationDates, dep.ID, envs)
	if err != nil {
		log.Fatal(err)
	}

	buildpackToml.Metadata.Dependencies = updatedDeps
	buildpackToml.Metadata.DependencyDeprecationDates = updatedDeprecationDates

	if err := updateBuildpackTomlFile(buildpackToml); err != nil {
		log.Fatalf("failed to update buildpack toml: %s", err)
	}

	if err := commitArtifacts(originalDeps, updatedDeps, dep, buildMetadata.TrackerStoryID); err != nil {
		log.Fatalf("failed to commit artifacts: %s", err)
	}
}

func loadAndConstructBinaryBuildsDependencyListForDep(dep Dependency, depOrchestratorConfig DependencyOrchestratorConfig) ([]Dependency, error) {
	var depsToAdd []Dependency

	buildMetadataPaths, err := filepath.Glob(filepath.Join("builds", "binary-builds-new", dep.ID, fmt.Sprintf("%s-*.json", dep.Version)))
	if err != nil {
		return depsToAdd, err
	}

	for _, buildMetadataPath := range buildMetadataPaths {
		deps, err := constructDependenciesFromBuildMetadata(dep, buildMetadataPath, depOrchestratorConfig)
		if err != nil {
			return depsToAdd, err
		}
		depsToAdd = append(depsToAdd, deps...)
	}
	return depsToAdd, nil
}

func constructDependenciesFromBuildMetadata(dep Dependency, buildMetadataPath string, depOrchestratorConfig DependencyOrchestratorConfig) ([]Dependency, error) {
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
			ID:           dep.ID,
			Name:         depOrchestratorConfig.V3DepNames[dep.ID],
			Sha256:       buildMetadata.Sha256,
			Source:       buildMetadata.Source.URL,
			SourceSha256: buildMetadata.Source.Sha256,
			Stacks:       []string{stack},
			URI:          buildMetadata.URL,
			Version:      dep.Version,
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
			return nil, errors.New(fmt.Sprintf("expected to find one stack name in filename (%s) but found: %v", filepath.Base(buildMetadataPath), matches[1:]))
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
			return nil, errors.New(fmt.Sprintf("%s is not a valid stack", stack))
		}
	}

	return stacks, nil
}
