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

func (buildpackTOML *BuildpackTOML) UpdateDependenciesWith(dep Dependency, newDeps Dependencies, versionsToKeep int) (Dependencies, Dependencies, error) {
	deps, err := buildpackTOML.loadDependencies()
	if err != nil {
		return nil, nil, errors.Wrap(err, "failed to decode dependencies")
	}

	updatedDeps, err := deps.Update(dep, newDeps, flags.versionLine, versionsToKeep)
	if err != nil {
		return nil, nil, errors.Wrap(err, "failed to add new dependencies to the dependencies list")
	}
	buildpackTOML.saveDependencies(updatedDeps)

	return deps, updatedDeps, nil
}

func (buildpackTOML *BuildpackTOML) UpdateDeprecationDatesWith(date DependencyDeprecationDate) error {
	deprecationDates, err := buildpackTOML.loadDeprecationDates()
	if err != nil {
		return errors.Wrap(err, "failed to decode deprecation dates")
	}

	updatedDeprecationDates, err := deprecationDates.Update(date)
	if err != nil {
		return errors.Wrap(err, "failed to update deprecation dates")
	}
	buildpackTOML.saveDeprecationDates(updatedDeprecationDates)

	return nil
}

func (buildpackTOML *BuildpackTOML) UpdateOrdersWith(dep Dependency) {
	buildpackTOML.Orders = buildpackTOML.Orders.Update(dep)
}

// This wont work until golang 1.13
//func (buildpackTOML *BuildpackTOML) RemoveEmptyMetadataFields() {
//	for k, v := range buildpackTOML.Metadata {
//		value := reflect.ValueOf(v)
//		if value.IsZero(v) {
//			delete(buildpackTOML.Metadata, k)
//		}
//	}
//}

func (buildpackTOML BuildpackTOML) WriteToFile(filepath string) error {
	buildpackTOMLFile, err := os.OpenFile(filepath, os.O_RDWR|os.O_CREATE, 0666)
	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("failed to open buildpack.toml at: %s", filepath))
	}
	defer buildpackTOMLFile.Close()

	if err := toml.NewEncoder(buildpackTOMLFile).Encode(buildpackTOML); err != nil {
		return errors.Wrap(err, "failed to update the buildpack.toml")
	}
	return nil
}

func (buildpackTOML BuildpackTOML) loadDependencies() (Dependencies, error) {
	var deps Dependencies
	err := mapstructure.Decode(buildpackTOML.Metadata[DependenciesKey], &deps)
	return deps, err
}

func (buildpackTOML *BuildpackTOML) saveDependencies(deps Dependencies) {
	buildpackTOML.Metadata[DependenciesKey] = deps
}

func (buildpackTOML BuildpackTOML) loadDeprecationDates() (DeprecationDates, error) {
	var deprecationDates DeprecationDates
	err := mapstructure.Decode(buildpackTOML.Metadata[DeprecationDatesKey], &deprecationDates)
	return deprecationDates, err
}

func (buildpackTOML *BuildpackTOML) saveDeprecationDates(dates DeprecationDates) {
	if len(dates) > 0 {
		buildpackTOML.Metadata[DeprecationDatesKey] = dates
	}
}
