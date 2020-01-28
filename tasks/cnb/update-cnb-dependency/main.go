package main

import (
	"flag"
	"log"
	"path/filepath"
	"strings"

	"github.com/pkg/errors"
)

var flags struct {
	dependencyBuildsConfig  string
	buildpackTOML           string
	sourceData              string
	binaryBuildsPath        string
	outputDir               string
	buildpackTOMLOutputPath string
	deprecationDate         string
	deprecationLink         string
	deprecationMatch        string
	versionLine             string
	versionsToKeep          int
}

func main() {
	flag.StringVar(&flags.dependencyBuildsConfig, "dependency-builds-config", "", "config for dependency builds pipeline")
	flag.StringVar(&flags.buildpackTOML, "buildpack-toml", "", "contents of buildpack.toml")
	flag.StringVar(&flags.sourceData, "source-data", "", "data from source of version bump")
	flag.StringVar(&flags.binaryBuildsPath, "binary-builds-path", "", "path to metadata for built binaries")
	flag.StringVar(&flags.outputDir, "output-dir", "", "directory to write buildpack.toml to")
	flag.StringVar(&flags.buildpackTOMLOutputPath, "buildpack-toml-output-path", "", "path to write new contents of buildpack.toml")
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

	depsToAdd, err := loadDependenciesFromBinaryBuilds(flags.binaryBuildsPath, config.Dep, config.Orchestrator)
	if err != nil {
		return errors.Wrap(err, "failed to construct list of dependencies to add")
	}

	originalDeps, updatedDeps, err := UpdateDependenciesWith(config.BuildpackTOML, config.Dep, depsToAdd, flags.versionsToKeep)
	if err != nil {
		return errors.Wrap(err, "failed to update the dependencies")
	}

	deprecationDate, err := NewDependencyDeprecationDate(flags.deprecationDate, flags.deprecationLink, config.Dep.ID, flags.versionLine, flags.deprecationMatch)
	if err != nil {
		return errors.Wrap(err, "failed to create a deprecation date")
	}

	err = UpdateDeprecationDatesWith(config.BuildpackTOML, deprecationDate)
	if err != nil {
		return errors.Wrap(err, "failed to update the deprecation dates")
	}

	config.BuildpackTOML.Orders = UpdateOrders(config.BuildpackTOML.Orders, config.Dep)

	// Won't work until golang 1.13
	//config.BuildpackTOML.RemoveEmptyMetadataFields()

	log.Printf("\nWriting to %s: %v\n\n", flags.buildpackTOMLOutputPath, config.BuildpackTOML)
	if err := config.BuildpackTOML.WriteToFile(filepath.Join(flags.outputDir, flags.buildpackTOMLOutputPath)); err != nil {
		return errors.Wrap(err, "failed to update buildpack toml")
	}

	commitMessage := GenerateCommitMessage(originalDeps, updatedDeps, config.Dep, flags.buildpackTOMLOutputPath, config.BuildMetadata.TrackerStoryID)
	log.Printf("\nCommitting with message: %s\n\n", commitMessage)
	if err := CommitArtifacts(commitMessage, flags.outputDir, flags.buildpackTOMLOutputPath); err != nil {
		return errors.Wrap(err, "failed to commit artifacts")
	}

	return nil
}
