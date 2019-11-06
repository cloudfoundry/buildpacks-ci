package utils

type ManifestYAML struct {
	Language        string `yaml:"language"`
	DefaultVersions []struct {
		Name    string `yaml:"name"`
		Version string `yaml:"version"`
	} `yaml:"default_versions"`
	IncludeFiles               []string `yaml:"include_files"`
	DependencyDeprecationDates []struct {
		VersionLine string `yaml:"version_line"`
		Name        string `yaml:"name"`
		Date        string `yaml:"date"`
		Link        string `yaml:"link"`
	} `yaml:"dependency_deprecation_dates"`
	Dependencies []struct {
		Name         string   `yaml:"name"`
		Version      string   `yaml:"version"`
		URI          string   `yaml:"uri"`
		Sha256       string   `yaml:"sha256"`
		CfStacks     []string `yaml:"cf_stacks"`
		Source       string   `yaml:"source"`
		SourceSha256 string   `yaml:"source_sha256"`
	} `yaml:"dependencies"`
	PrePackage string `yaml:"pre_package"`
}
