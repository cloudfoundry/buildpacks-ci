package main

import (
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
	"github.com/mitchellh/mapstructure"
	"github.com/pkg/errors"
)

type BuildpackTOML struct {
	API       string `toml:"api"`
	Buildpack struct {
		ID      string `toml:"id"`
		Name    string `toml:"name"`
		Version string `toml:"version"`
	} `toml:"buildpack"`
	Metadata Metadata `toml:"metadata"`
	Orders   Orders   `toml:"order"`
	Stacks   Stacks   `toml:"stacks"`
}

type Metadata map[string]interface{}

var (
	IncludeFilesKey     = "include_files"
	PrePackageKey       = "pre_package"
	DeprecationDatesKey = "dependency_deprecation_dates"
	DependenciesKey     = "dependencies"
	DefaultVersionsKey  = "default-versions"
)

func (buildpackTOML BuildpackTOML) Dependencies() (Dependencies, error) {
	var deps Dependencies
	err := mapstructure.Decode(buildpackTOML.Metadata[DependenciesKey], &deps)
	return deps, err
}

func (buildpackTOML *BuildpackTOML) SaveDependencies(deps Dependencies) {
	buildpackTOML.Metadata[DependenciesKey] = deps
}

func (buildpackTOML BuildpackTOML) DeprecationDates() (DeprecationDates, error) {
	var deprecationDates DeprecationDates
	err := mapstructure.Decode(buildpackTOML.Metadata[DeprecationDatesKey], &deprecationDates)
	return deprecationDates, err
}

func (buildpackTOML *BuildpackTOML) SaveDeprecationDates(dates DeprecationDates) {
	if len(dates) > 0 {
		buildpackTOML.Metadata[DeprecationDatesKey] = dates // Metadata is untyped so we can get empty values
	}
}

func (buildpackTOML BuildpackTOML) WriteToFile(filepath string) error {
	buildpackTOMLFile, err := os.OpenFile(filepath, os.O_RDWR|os.O_CREATE, 0666)
	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("failed to open buildpack.toml at: %s", filepath))
	}
	defer buildpackTOMLFile.Close()

	if err := toml.NewEncoder(buildpackTOMLFile).Encode(buildpackTOML); err != nil {
		return errors.Wrap(err, "failed to save updated buildpack.toml")
	}
	return nil
}
