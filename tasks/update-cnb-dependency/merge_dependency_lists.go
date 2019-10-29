package main

import (
	"sort"
)

func MergeDependencyLists(existingDeps, newDeps []Dependency) ([]Dependency, error) {
	depsMap := map[string]Dependency{}

	for _, dep := range existingDeps {
		depsMap[makeKey(dep)] = dep
	}
	for _, dep := range newDeps {
		depsMap[makeKey(dep)] = dep
	}

	var allDeps []Dependency
	for _, dep := range depsMap {
		allDeps = append(allDeps, dep)
	}

	sort.Slice(allDeps, sortDependencies(allDeps))
	return allDeps, nil
}

func makeKey(dep Dependency) string { return dep.ID + dep.Version + dep.Stacks[0] }
