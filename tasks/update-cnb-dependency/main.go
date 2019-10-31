package main

import (
	"log"
)

func main() {
	envs, depOrchestratorConfig, buildpackToml, dep, buildMetadata, err := loadResources()
	if err != nil {
		log.Fatalf("Failed to load task resources: %s", err)
	}

	depsToAdd, err := loadDependenciesFromBinaryBuildsForDep(dep, depOrchestratorConfig, envs.IncludeTiny)
	if err != nil {
		log.Fatalf("Failed to construct list of dependencies to add: %s", err)
	}

	originalDeps := buildpackToml.LoadExpandedDependencies()
	updatedDeps, err := MergeDependencyLists(originalDeps, depsToAdd)
	if err != nil {
		log.Fatal(err)
	}

	updatedDeps, err = RemoveOldDeps(updatedDeps, dep.ID,
		envs.VersionLine, envs.VersionsToKeep)
	if err != nil {
		log.Fatal(err)
	}

	updatedOrder := UpdateOrderDependencyVersion(buildpackToml.Order, dep)

	updatedDeprecationDates, err := UpdateDeprecationDatesWithDependency(
		buildpackToml.Metadata.DependencyDeprecationDates, envs.DeprecationDate)
	if err != nil {
		log.Fatal(err)
	}

	buildpackToml.Metadata.Dependencies = updatedDeps
	buildpackToml.Metadata.DependencyDeprecationDates = updatedDeprecationDates
	buildpackToml.Order = updatedOrder

	if err := buildpackToml.WriteToFile("artifacts/buildpack.toml"); err != nil {
		log.Fatalf("failed to update buildpack toml: %s", err)
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, dep, buildMetadata.TrackerStoryID)
	if err := CommitArtifacts(commitMessage); err != nil {
		log.Fatalf("failed to commit artifacts: %s", err)
	}
}
