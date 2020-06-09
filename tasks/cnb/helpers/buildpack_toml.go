package helpers

import (
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
	"github.com/pkg/errors"
)

type BuildpackTOML struct {
	API       string `toml:"api"`
	Buildpack struct {
		ID       string `toml:"id"`
		Name     string `toml:"name"`
		Version  string `toml:"version,omitempty"`
		Homepage string `toml:"homepage,omitempty"`
	} `toml:"buildpack"`
	Metadata Metadata `toml:"metadata"`
	Orders   []Order  `toml:"order"`
	Stacks   []Stack  `toml:"stacks"`
}

type Metadata map[string]interface{}

type Order struct {
	Group []Group `toml:"group"`
}

type Group struct {
	ID       string `toml:"id"`
	Version  string `toml:"version"`
	Optional bool   `toml:"optional,omitempty"`
}

type Stack struct {
	ID     string   `toml:"id"`
	Mixins []string `toml:"mixins,omitempty"`
}

type Dependency struct {
	DeprecationDate string   `mapstructure:"deprecation_date" toml:"deprecation_date,omitempty"`
	ID              string   `toml:"id"`
	Name            string   `toml:"name,omitempty"`
	SHA256          string   `toml:"sha256"`
	Source          string   `toml:"source,omitempty"`
	SourceSHA256    string   `mapstructure:"source_sha256" toml:"source_sha256,omitempty"`
	Stacks          []string `toml:"stacks"`
	URI             string   `toml:"uri"`
	Version         string   `toml:"version"`
}

const (
	IncludeFilesKey    = "include_files"
	PrePackageKey      = "pre_package"
	DependenciesKey    = "dependencies"
	DefaultVersionsKey = "default-versions"
	RuntimeToSDKsKey   = "runtime-to-sdks"
)

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
	buildpackTOMLFile, err := os.Create(filepath)
	if err != nil {
		return errors.Wrap(err, fmt.Sprintf("failed to open buildpack.toml at: %s", filepath))
	}
	defer buildpackTOMLFile.Close()

	if err := toml.NewEncoder(buildpackTOMLFile).Encode(buildpackTOML); err != nil {
		return errors.Wrap(err, "failed to update the buildpack.toml")
	}
	return nil
}
