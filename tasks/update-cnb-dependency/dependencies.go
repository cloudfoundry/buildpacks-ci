package main

import (
	"errors"
	"fmt"
	"path/filepath"
	"sort"

	"github.com/blang/semver"
)

type Dependencies []Dependency

type Dependency struct {
	ID           string   `toml:"id"`
	Name         string   `toml:"name,omitempty"`
	SHA256       string   `toml:"sha256"`
	Source       string   `toml:"source,omitempty"`
	SourceSHA256 string   `mapstructure:"source_sha256" toml:"source_sha256,omitempty"`
	Stacks       []string `toml:"stacks"`
	URI          string   `toml:"uri"`
	Version      string   `toml:"version"`
}

func (deps Dependencies) MergeWith(newDeps Dependencies) (Dependencies, error) {
	depsMap := map[string]Dependency{}

	for _, dep := range deps {
		depsMap[makeKeyWithStack(dep)] = dep
	}
	for _, dep := range newDeps {
		depsMap[makeKeyWithStack(dep)] = dep
	}

	allDeps := Dependencies{}
	for _, dep := range depsMap {
		allDeps = append(allDeps, dep)
	}

	sort.Slice(allDeps, allDeps.sortDependencies())
	return allDeps, nil
}

func (deps Dependencies) RemoveOldDeps(depID, versionLine string, keepN int) (Dependencies, error) {
	if keepN <= 0 {
		return nil, errors.New("please specify a valid number of versions (>0) to retain")
	}

	retainedDeps := Dependencies{}
	retainedPerStack := map[string]int{}

	versionLineConstraint, err := getVersionLineConstraint(versionLine)
	if err != nil {
		return nil, err
	}

	for i := len(deps) - 1; i >= 0; i-- {
		dep := deps[i]
		depVersion, err := semver.Parse(dep.Version)
		if err != nil {
			return nil, err
		}

		differentDep := dep.ID != depID
		differentVersionLine := !versionLineConstraint(depVersion)
		haveNotRetainedNForStack := retainedPerStack[dep.Stacks[0]] < keepN

		if differentDep || differentVersionLine {
			retainedDeps = append(retainedDeps, dep)
		} else if haveNotRetainedNForStack {
			retainedDeps = append(retainedDeps, dep)
			retainedPerStack[dep.Stacks[0]]++
		}
	}

	sort.Slice(retainedDeps, retainedDeps.sortDependencies())
	return retainedDeps, nil
}

func (deps Dependencies) sortDependencies() func(i, j int) bool {
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

func (deps Dependencies) ExpandByStack() Dependencies {
	var expandedDeps Dependencies
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

func loadDependenciesFromBinaryBuilds(binaryBuildsPath string, dep Dependency, depOrchestratorConfig DependencyOrchestratorConfig) (Dependencies, error) {
	var depsToAdd Dependencies

	buildMetadataPaths, err := filepath.Glob(filepath.Join(binaryBuildsPath, dep.ID, fmt.Sprintf("%s-*.json", dep.Version)))
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

func (deps Dependencies) containsDependency(dep Dependency) bool {
	_, exists := deps.findDependency(dep)
	return exists
}

func (deps Dependencies) findDependency(dep Dependency) (Dependency, bool) {
	for _, d := range deps {
		if d.ID == dep.ID && d.Version == dep.Version && d.Stacks[0] == dep.Stacks[0] {
			return d, true
		}
	}
	return Dependency{}, false
}

func (deps Dependencies) CollapseEqualDependecies() Dependencies {
	depsMap := map[string]Dependency{}
	for _, dep := range deps {
		key := makeKeyWithoutStack(dep)
		if mapDep, exists := depsMap[key]; exists {
			mapDep.Stacks = combineStacks(mapDep.Stacks, dep.Stacks)
			depsMap[key] = mapDep
		} else {
			depsMap[key] = dep
		}
	}

	allDeps := Dependencies{}
	for _, dep := range depsMap {
		allDeps = append(allDeps, dep)
	}

	sort.Slice(allDeps, allDeps.sortDependencies())
	return allDeps
}

func combineStacks(a, b []string) []string {
	stacksMap := map[string]bool{}

	for _, stack := range a {
		stacksMap[stack] = true
	}

	for _, stack := range b {
		stacksMap[stack] = true
	}

	var allStacks []string
	for stack, _ := range stacksMap {
		allStacks = append(allStacks, stack)
	}

	sort.Strings(allStacks)
	return allStacks
}

func makeKeyWithStack(dep Dependency) string { return dep.ID + dep.Version + dep.Stacks[0] }

func makeKeyWithoutStack(dep Dependency) string {
	return dep.ID + dep.Version + dep.URI + dep.SHA256 + dep.Source + dep.SourceSHA256
}

func constructDependenciesFromBuildMetadata(dep Dependency, buildMetadataPath string, depOrchestratorConfig DependencyOrchestratorConfig) (Dependencies, error) {
	var buildMetadata BuildMetadata
	if err := loadJSON(buildMetadataPath, &buildMetadata); err != nil {
		return nil, err
	}

	stacks, err := determineStacks(buildMetadataPath, dep, depOrchestratorConfig)
	if err != nil {
		return nil, err
	}

	var deps Dependencies
	for _, stack := range stacks {
		deps = append(deps, Dependency{
			ID:           dep.ID,
			Name:         depOrchestratorConfig.V3DepNames[dep.ID],
			SHA256:       buildMetadata.SHA256,
			Source:       buildMetadata.Source.URL,
			SourceSHA256: buildMetadata.Source.SHA256,
			Stacks:       []string{stack},
			URI:          buildMetadata.URL,
			Version:      dep.Version,
		})
	}
	return deps, nil
}

func arrayContains(item string, array []string) bool {
	for _, element := range array {
		if item == element {
			return true
		}
	}
	return false
}
