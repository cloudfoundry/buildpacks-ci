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
	config, err := NewUpdateConfig()
	if err != nil {
		return errors.Wrap(err, "failed to load task resources")
	}

	depsToAdd, err := loadDependenciesFromBinaryBuilds(config.Dep, config.Orchestrator)
	if err != nil {
		return errors.Wrap(err, "failed to construct list of dependencies to add")
	}

	originalDeps := config.BuildpackTOML.Metadata.Dependencies.ExpandByStack()
	updatedDeps, err := originalDeps.MergeWith(depsToAdd)
	if err != nil {
		return errors.Wrap(err, "failed to merge dependency lists")
	}

	updatedDeps, err = updatedDeps.RemoveOldDeps(config.Dep.ID, config.Envs.VersionLine, config.Envs.VersionsToKeep)
	if err != nil {
		return errors.Wrap(err, "failed to remove old dependencies")
	}

	updatedOrder := config.BuildpackTOML.Orders.UpdateOrderDependencyVersion(config.Dep)

	updatedDeprecationDates, err := config.BuildpackTOML.Metadata.DependencyDeprecationDates.Update(config.Envs.DeprecationDate)
	if err != nil {
		return errors.Wrap(err, "failed to update deprecation dates")
	}

	config.BuildpackTOML.Metadata.Dependencies = updatedDeps
	config.BuildpackTOML.Metadata.DependencyDeprecationDates = updatedDeprecationDates
	config.BuildpackTOML.Orders = updatedOrder

	if err := config.BuildpackTOML.WriteToFile(filepath.Join("artifacts", "buildpack.toml")); err != nil {
		return errors.Wrap(err, "failed to update buildpack toml")
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, config.Dep, config.BuildMetadata.TrackerStoryID)
	if err := CommitArtifacts(commitMessage); err != nil {
		return errors.Wrap(err, "failed to commit artifacts")
	}

	return nil
}
