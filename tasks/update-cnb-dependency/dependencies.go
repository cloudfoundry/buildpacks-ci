package main

import "github.com/blang/semver"

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
