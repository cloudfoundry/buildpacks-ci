package main

import (
	"os"
	"time"

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

type Dependency struct {
	ID           string
	Name         string `toml:",omitempty"`
	Sha256       string
	Source       string `toml:",omitempty"`
	SourceSha256 string `toml:"source_sha256,omitempty"`
	Stacks       []string
	URI          string
	Version      string
}

type DependencyDeprecationDate struct {
	Date        time.Time
	Link        string
	Name        string
	VersionLine string `toml:"version_line"`
	Match       string `toml:",omitempty"`
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

func updateBuildpackTomlFile(buildpackToml BuildpackToml) error {
	buildpackTOML, err := os.OpenFile("artifacts/buildpack.toml", os.O_RDWR|os.O_CREATE, 0666)
	if err != nil {
		return errors.Wrap(err, "failed to open buildpack.toml")
	}
	defer buildpackTOML.Close()

	if err := toml.NewEncoder(buildpackTOML).Encode(buildpackToml); err != nil {
		return errors.Wrap(err, "failed to save updated buildpack.toml")
	}
	return nil
}
