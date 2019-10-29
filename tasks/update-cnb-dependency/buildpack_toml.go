package main

import (
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
	"github.com/pkg/errors"
)

type BuildpackToml struct {
	API       string
	Buildpack struct {
		ID      string
		Name    string
		Version string
	} `toml:"buildpack"`
	Metadata Metadata
	Order    []Order
	Stacks   []Stack
}

type Metadata struct {
	IncludeFiles               []string `toml:"include_files"`
	Dependencies               []Dependency
	DependencyDeprecationDates []DependencyDeprecationDate `toml:"dependency_deprecation_dates"`
}

type Order struct {
	Group []Group
}

type Group struct {
	ID      string
	Version string
}

type Stack struct {
	ID string
}

func (buildpackToml BuildpackToml) LoadExpandedDependencies() []Dependency {
	return expandDependenciesForEachStack(buildpackToml.Metadata.Dependencies)
}

func (buildpackToml BuildpackToml) WriteToFile(filepath string) error {
	buildpackTomlFile, err := os.OpenFile(filepath, os.O_RDWR|os.O_CREATE, 0666)
	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("failed to open buildpack.toml at: %s", filepath))
	}
	defer buildpackTomlFile.Close()

	if err := toml.NewEncoder(buildpackTomlFile).Encode(buildpackToml); err != nil {
		return errors.Wrap(err, "failed to save updated buildpack.toml")
	}
	return nil
}
