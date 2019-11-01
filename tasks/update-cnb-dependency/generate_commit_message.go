package main

import (
	"fmt"
	"sort"
	"strings"
)

func GenerateCommitMessage(oldDeps, newDeps Dependencies, dep Dependency, storyID int) string {
	added := false
	rebuilt := false
	stacks := map[string]bool{}
	removedDeps := map[string]bool{}

	for _, newDep := range newDeps {
		if newDep.ID != dep.ID || newDep.Version != dep.Version {
			continue
		}

		oldDep, exists := oldDeps.findDependency(newDep)
		if exists {
			if oldDep.SHA256 != newDep.SHA256 || oldDep.URI != newDep.URI {
				rebuilt = true
				stacks[newDep.Stacks[0]] = true
			}
		} else {
			added = true
			stacks[newDep.Stacks[0]] = true
		}
	}

	for _, dep := range oldDeps {
		if dep.ID != dep.ID {
			continue
		}

		if !newDeps.containsDependency(dep) {
			removedDeps[dep.ID+" "+dep.Version] = true
			stacks[dep.Stacks[0]] = true
		}
	}

	if !added && !rebuilt && len(removedDeps) == 0 {
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

func joinMap(m map[string]bool) string {
	var a []string
	for s := range m {
		a = append(a, s)
	}
	sort.Strings(a)
	return strings.Join(a, ", ")
}
