package main

import (
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
	"github.com/pkg/errors"
)

type BuildpackTOML struct {
	API       string
	Buildpack struct {
		ID      string
		Name    string
		Version string
	} `toml:"buildpack"`
	Metadata Metadata
	Orders   Orders `toml:"order"`
	Stacks   Stacks `toml:"stack"`
}

type Metadata struct {
	IncludeFiles               []string `toml:"include_files"`
	Dependencies               Dependencies
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
