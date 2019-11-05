package main

import (
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
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

type Metadata struct {
	IncludeFiles               []string         `toml:"include_files"`
	PrePackage                 string           `toml:"pre_package"`
	Dependencies               Dependencies     `toml:"dependencies"`
	DependencyDeprecationDates DeprecationDates `toml:"dependency_deprecation_dates"`
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
