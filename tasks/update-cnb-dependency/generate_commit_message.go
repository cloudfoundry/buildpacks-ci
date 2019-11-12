package main

import (
	"fmt"
	"sort"
	"strings"
)

func GenerateCommitMessage(oldDeps, newDeps Dependencies, dep Dependency, storyID int) string {
	added, rebuilt, stacks := findAddedDeps(dep, oldDeps, newDeps)

	removedDeps, stacks := findRemovedDeps(dep, oldDeps, newDeps, stacks)

	return formCommitMessage(dep, added, rebuilt, removedDeps, stacks, storyID)
}

func findAddedDeps(dep Dependency, oldDeps, newDeps Dependencies) (bool, bool, map[string]bool) {
	var added, rebuilt bool
	// Use maps to ensure no duplicates
	stacks := map[string]bool{}

	for _, newDep := range newDeps {
		if newDep.ID != dep.ID || newDep.Version != dep.Version {
			continue
		}

		oldDep, exists := oldDeps.findDependency(newDep)
		if exists && rebuild(oldDep, newDep) {
			rebuilt = true
		} else if !exists {
			added = true
		} else {
			continue
		}

		for _, stack := range newDep.Stacks {
			stacks[stack] = true
		}
	}

	return added, rebuilt, stacks
}

func findRemovedDeps(dep Dependency, oldDeps, newDeps Dependencies, stacks map[string]bool) (map[string]bool, map[string]bool) {
	removedDeps := map[string]bool{}

	for _, oldDep := range oldDeps {
		if oldDep.ID != dep.ID {
			continue
		}

		if !newDeps.containsDependency(oldDep) {
			removedDeps[oldDep.ID+" "+oldDep.Version] = true
			for _, stack := range oldDep.Stacks {
				stacks[stack] = true
			}
		}
	}

	return removedDeps, stacks
}

func formCommitMessage(dep Dependency, added, rebuilt bool, removedDeps, stacks map[string]bool, storyID int) string {
	if noChanges(added, rebuilt, removedDeps) {
		return ""
	}

	var commitMessage string
	if added {
		commitMessage = fmt.Sprintf("Add %s %s", dep.ID, dep.Version)
	} else {
		commitMessage = fmt.Sprintf("Rebuild %s %s", dep.ID, dep.Version)
	}

	if len(removedDeps) > 0 {
		commitMessage += fmt.Sprintf(", remove %s", joinMap(removedDeps))
	}

	commitMessage += fmt.Sprintf("\n\nfor stack(s) %s [#%d]", joinMap(stacks), storyID)

	return commitMessage
}

func noChanges(added, rebuilt bool, removedDeps map[string]bool) bool {
	return !added && !rebuilt && len(removedDeps) == 0
}

func rebuild(dep, newDep Dependency) bool {
	return dep.SHA256 != newDep.SHA256 || dep.URI != newDep.URI
}

func joinMap(m map[string]bool) string {
	var a []string
	for s := range m {
		a = append(a, s)
	}
	sort.Strings(a)
	return strings.Join(a, ", ")
}
