package main

import (
	"errors"
	"fmt"
	"path/filepath"
	"regexp"

	"github.com/blang/semver"
)

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

const AnyStack = "any-stack"
const TinyStack = "tiny"

func sortDependencies(deps []Dependency) func(i, j int) bool {
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

func expandDependenciesForEachStack(deps []Dependency) []Dependency {
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

func loadDependenciesFromBinaryBuildsForDep(dep Dependency, depOrchestratorConfig DependencyOrchestratorConfig, includeTiny bool) ([]Dependency, error) {
	var depsToAdd []Dependency

	buildMetadataPaths, err := filepath.Glob(filepath.Join("builds", "binary-builds-new", dep.ID, fmt.Sprintf("%s-*.json", dep.Version)))
	if err != nil {
		return depsToAdd, err
	}

	for _, buildMetadataPath := range buildMetadataPaths {
		deps, err := constructDependenciesFromBuildMetadata(dep, buildMetadataPath, depOrchestratorConfig, includeTiny)
		if err != nil {
			return depsToAdd, err
		}
		depsToAdd = append(depsToAdd, deps...)
	}
	return depsToAdd, nil
}

func constructDependenciesFromBuildMetadata(dep Dependency, buildMetadataPath string, depOrchestratorConfig DependencyOrchestratorConfig, includeTiny bool) ([]Dependency, error) {
	var buildMetadata BuildMetadata
	if err := loadJSON(buildMetadataPath, &buildMetadata); err != nil {
		return nil, err
	}

	stacks, err := determineStacks(buildMetadataPath, depOrchestratorConfig.V3Stacks, depOrchestratorConfig.DeprecatedStacks, includeTiny)
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

func determineStacks(buildMetadataPath string, stacksMap map[string]string, deprecatedStacks []string, includeTiny bool) ([]string, error) {
	stackRegexp := regexp.MustCompile(`\/(?:\.|\d)*-(.*)\.json$`)
	matches := stackRegexp.FindStringSubmatch(buildMetadataPath)
	if len(matches) != 2 {
		return nil, errors.New(fmt.Sprintf("expected to find one stack name in filename (%s) but found: %v", filepath.Base(buildMetadataPath), matches[1:]))
	}
	stack := matches[1]

	if stack == AnyStack {
		return handleAnyStack(stacksMap, includeTiny)
	} else if stackIsDeprecated(stack, deprecatedStacks) {
		return nil, nil
	}

	for stackName, stackID := range stacksMap {
		if stack == stackName {
			return []string{stackID}, nil
		}
	}
	return nil, errors.New(fmt.Sprintf("%s is not a valid stack", stack))
}

func handleAnyStack(stacksMap map[string]string, includeTiny bool) ([]string, error) {
	var stacks []string
	for stack, stackID := range stacksMap {
		if stack == TinyStack && !includeTiny {
			continue
		}
		stacks = append(stacks, stackID)
	}

	if len(stacks) == 0 {
		return nil, errors.New("stack is 'any-stack' but no stacks are configured, check dependency-builds.yml")
	}
	return stacks, nil
}

func stackIsDeprecated(stack string, deprecatedStacks []string) bool {
	for _, deprecatedStack := range deprecatedStacks {
		if stack == deprecatedStack {
			return true
		}
	}
	return false
}
