package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"path/filepath"
	"sort"

	"github.com/blang/semver"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	"github.com/pkg/errors"
)

type Dependencies []helpers.Dependency

func (deps Dependencies) Update(dep helpers.Dependency, depsToAdd Dependencies, versionLine string, versionsToKeep int) (Dependencies, error) {
	expandedDeps := deps.ExpandByStack()
	mergedDeps := expandedDeps.MergeWith(depsToAdd)
	updatedDeps, err := mergedDeps.RemoveOldDeps(dep.ID, versionLine, versionsToKeep)
	if err != nil {
		return Dependencies{}, errors.Wrap(err, "failed to remove old dependencies")
	}
	return updatedDeps.CollapseByStack(), nil
}

func (deps Dependencies) MergeWith(newDeps Dependencies) Dependencies {
	depsMap := map[string]helpers.Dependency{}

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

	sort.Slice(allDeps, allDeps.SortDependencies())
	return allDeps
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

	sort.Slice(retainedDeps, retainedDeps.SortDependencies())
	return retainedDeps, nil
}

func (deps Dependencies) CollapseByStack() Dependencies {
	depsMap := map[string]helpers.Dependency{}
	for _, dep := range deps {
		key := makeKeyWithoutStack(dep)
		if mapDep, exists := depsMap[key]; exists {
			//Every dependency will be expanded, and will only have 1 stack
			mapDep.Stacks = append(mapDep.Stacks, dep.Stacks[0])
			depsMap[key] = mapDep
		} else {
			depsMap[key] = dep
		}
	}

	allDeps := Dependencies{}
	for _, dep := range depsMap {
		sort.Strings(dep.Stacks)
		allDeps = append(allDeps, dep)
	}

	sort.Slice(allDeps, allDeps.SortDependencies())
	return allDeps
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

func (deps Dependencies) SortDependencies() func(i, j int) bool {
	return func(i, j int) bool {
		if deps[i].ID != deps[j].ID {
			return deps[i].ID < deps[j].ID
		}

		firstVersion := semver.MustParse(deps[i].Version)
		secondVersion := semver.MustParse(deps[j].Version)

		if firstVersion.EQ(secondVersion) {
			return compareStacks(deps[i].Stacks, deps[j].Stacks)
		}

		return firstVersion.LT(secondVersion)
	}
}

func compareStacks(a, b []string) bool {
	for i, stack := range a {
		if i >= len(b) {
			return false
		}

		if stack != b[i] {
			return stack < b[i]
		}
	}

	return true
}

func loadDependenciesFromBinaryBuilds(binaryBuildsPath string, dep helpers.Dependency, depOrchestratorConfig DependencyOrchestratorConfig) (Dependencies, error) {
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

func (deps Dependencies) containsDependency(dep helpers.Dependency) bool {
	_, exists := deps.findDependency(dep)
	return exists
}

func (deps Dependencies) findDependency(dep helpers.Dependency) (helpers.Dependency, bool) {
	sort.Strings(dep.Stacks)
	for _, d := range deps {
		sort.Strings(d.Stacks)

		if d.ID == dep.ID && d.Version == dep.Version && compareStacks(dep.Stacks, d.Stacks) {
			return d, true
		}
	}
	return helpers.Dependency{}, false
}

func makeKeyWithStack(dep helpers.Dependency) string { return dep.ID + dep.Version + dep.Stacks[0] }

func makeKeyWithoutStack(dep helpers.Dependency) string {
	return dep.ID + dep.Version + dep.URI + dep.SHA256 + dep.Source + dep.SourceSHA256
}

func constructDependenciesFromBuildMetadata(dep helpers.Dependency, buildMetadataPath string, depOrchestratorConfig DependencyOrchestratorConfig) (Dependencies, error) {
	contents, err := ioutil.ReadFile(buildMetadataPath)
	if err != nil {
		return nil, err
	}
	var buildMetadata BuildMetadata
	if err := json.Unmarshal(contents, &buildMetadata); err != nil {
		return nil, err
	}

	stacks, err := determineStacks(buildMetadataPath, dep, depOrchestratorConfig)
	if err != nil {
		return nil, err
	}

	var deps Dependencies
	for _, stack := range stacks {
		deps = append(deps, helpers.Dependency{
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
