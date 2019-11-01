package main

import (
	"flag"
	"log"
	"path/filepath"
	"strings"

	"github.com/pkg/errors"
)

var flags struct {
	dependencyBuildsConfig string
	buildpackTOML          string
	sourceData             string
	binaryBuildsPath       string
	outputDir              string
	deprecationDate        string
	deprecationLink        string
	deprecationMatch       string
	versionLine            string
	versionsToKeep         int
}

func main() {
	flag.StringVar(&flags.dependencyBuildsConfig, "dependency-builds-config", "", "config for dependency builds pipeline")
	flag.StringVar(&flags.buildpackTOML, "buildpack-toml", "", "contents of buildpack.toml")
	flag.StringVar(&flags.sourceData, "source-data", "", "data from source of version bump")
	flag.StringVar(&flags.binaryBuildsPath, "binary-builds-path", "", "path to metadata for built binaries")
	flag.StringVar(&flags.outputDir, "output-dir", "", "directory to write buildpack.toml to")
	flag.StringVar(&flags.deprecationDate, "deprecation-date", "", "deprecation date for version line")
	flag.StringVar(&flags.deprecationLink, "deprecation-link", "", "deprecation link for version line")
	flag.StringVar(&flags.deprecationMatch, "deprecation-match", "", "")
	flag.StringVar(&flags.versionLine, "version-line", "", "version line to use for dependency removal and deprecation date update")
	flag.IntVar(&flags.versionsToKeep, "versions-to-keep", 2, "number of versions to keep for the version line")
	flag.Parse()

	flags.versionLine = strings.ToLower(flags.versionLine)

	if err := updateCNBDependencies(); err != nil {
		log.Fatalln(err)
	}
}

func updateCNBDependencies() error {
	config, err := NewUpdateConfig(flags.dependencyBuildsConfig, flags.buildpackTOML, flags.sourceData, flags.binaryBuildsPath)
	if err != nil {
		return errors.Wrap(err, "failed to load task resources")
	}

	deprecationDate, err := NewDependencyDeprecationDate(flags.deprecationDate, flags.deprecationLink, config.Dep.ID, flags.versionLine, flags.deprecationMatch)
	if err != nil {
		return errors.Wrap(err, "failed to create deprecation date")
	}

	depsToAdd, err := loadDependenciesFromBinaryBuilds(flags.binaryBuildsPath, config.Dep, config.Orchestrator)
	if err != nil {
		return errors.Wrap(err, "failed to construct list of dependencies to add")
	}

	originalDeps := config.BuildpackTOML.Metadata.Dependencies.ExpandByStack()
	updatedDeps, err := originalDeps.MergeWith(depsToAdd)
	if err != nil {
		return errors.Wrap(err, "failed to merge dependency lists")
	}

	updatedDeps, err = updatedDeps.RemoveOldDeps(config.Dep.ID, flags.versionLine, flags.versionsToKeep)
	if err != nil {
		return errors.Wrap(err, "failed to remove old dependencies")
	}

	updatedOrder := config.BuildpackTOML.Orders.UpdateOrderDependencyVersion(config.Dep)

	updatedDeprecationDates, err := config.BuildpackTOML.Metadata.DependencyDeprecationDates.Update(deprecationDate)
	if err != nil {
		return errors.Wrap(err, "failed to update deprecation dates")
	}

	config.BuildpackTOML.Metadata.Dependencies = updatedDeps
	config.BuildpackTOML.Metadata.DependencyDeprecationDates = updatedDeprecationDates
	config.BuildpackTOML.Orders = updatedOrder

	if err := config.BuildpackTOML.WriteToFile(filepath.Join(flags.outputDir, "buildpack.toml")); err != nil {
		return errors.Wrap(err, "failed to update buildpack toml")
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, config.Dep, config.BuildMetadata.TrackerStoryID)
	if err := CommitArtifacts(commitMessage, flags.outputDir); err != nil {
		return errors.Wrap(err, "failed to commit artifacts")
	}

	return nil
}
