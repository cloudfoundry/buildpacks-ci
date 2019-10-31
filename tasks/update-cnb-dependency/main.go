package main

import (
	"log"
	"path/filepath"

	"github.com/pkg/errors"
)

func main() {
	if err := updateCNBDependencies(); err != nil {
		log.Fatalln(err)
	}
}

func updateCNBDependencies() error {
	envs, depOrchestratorConfig, buildpackToml, dep, buildMetadata, err := loadResources()
	if err != nil {
		return errors.Wrap(err, "failed to load task resources")
	}

	depsToAdd, err := loadDependenciesFromBinaryBuildsForDep(dep, depOrchestratorConfig)
	if err != nil {
		return errors.Wrap(err, "failed to construct list of dependencies to add")
	}

	originalDeps := buildpackToml.LoadExpandedDependencies()
	updatedDeps, err := originalDeps.MergeDependencyLists(depsToAdd)
	if err != nil {
		return errors.Wrap(err, "failed to merge dependency lists")
	}

	updatedDeps, err = updatedDeps.RemoveOldDeps(dep.ID, envs.VersionLine, envs.VersionsToKeep)
	if err != nil {
		return errors.Wrap(err, "failed to remove old dependencies")
	}

	updatedOrder := buildpackToml.Orders.UpdateOrderDependencyVersion(dep)

	updatedDeprecationDates, err := buildpackToml.Metadata.DependencyDeprecationDates.UpdateDeprecationDatesWithDependency(envs.DeprecationDate)
	if err != nil {
		return errors.Wrap(err, "failed to update deprecation dates")
	}

	buildpackToml.Metadata.Dependencies = updatedDeps
	buildpackToml.Metadata.DependencyDeprecationDates = updatedDeprecationDates
	buildpackToml.Orders = updatedOrder

	if err := buildpackToml.WriteToFile(filepath.Join("artifacts", "buildpack.toml")); err != nil {
		return errors.Wrap(err, "failed to update buildpack toml")
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, dep, buildMetadata.TrackerStoryID)
	if err := CommitArtifacts(commitMessage); err != nil {
		return errors.Wrap(err, "failed to commit artifacts")
	}

	return nil
}
