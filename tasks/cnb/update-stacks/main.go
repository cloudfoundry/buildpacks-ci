package main

import (
	"flag"
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
	"sort"

	"github.com/BurntSushi/toml"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	"github.com/mitchellh/mapstructure"
	"gopkg.in/yaml.v2"
)

var flags struct {
	dependencyBuildsConfig  string
	buildpackTOMLContents   string
	outputDir               string
	buildpackTOMLOutputPath string
}

func main() {
	flag.StringVar(&flags.dependencyBuildsConfig, "dependency-builds-config", "", "config for dependency builds pipeline")
	flag.StringVar(&flags.buildpackTOMLContents, "buildpack-toml", "", "contents of buildpack.toml")
	flag.StringVar(&flags.outputDir, "output-dir", "", "directory to write buildpack.toml to")
	flag.StringVar(&flags.buildpackTOMLOutputPath, "buildpack-toml-output-path", "", "path to write new contents of buildpack.toml")
	flag.Parse()

	if err := run(); err != nil {
		log.Fatalln(err)
	}
}

type dependencyBuildsConfig struct {
	Dependencies map[string]struct {
		Mixins map[string][]string `yaml:"mixins"`
	} `yaml:"dependencies"`
}

func run() error {
	var buildpackTOML helpers.BuildpackTOML
	if _, err := toml.Decode(flags.buildpackTOMLContents, &buildpackTOML); err != nil {
		return fmt.Errorf("failed to parse buildpack.toml: %w", err)
	}

	var config dependencyBuildsConfig
	if err := yaml.Unmarshal([]byte(flags.dependencyBuildsConfig), &config); err != nil {
		return fmt.Errorf("failed to unmarshal dependency-builds config: %w", err)
	}

	buildpackTOML, err := updateStacks(buildpackTOML, config)
	if err != nil {
		return err
	}

	log.Printf("Writing to %s: %v\n\n", flags.buildpackTOMLOutputPath, buildpackTOML)
	if err := buildpackTOML.WriteToFile(filepath.Join(flags.outputDir, flags.buildpackTOMLOutputPath)); err != nil {
		return fmt.Errorf("failed to write buildpack.toml: %w", err)
	}

	if err := commitBuildpackTOML(flags.outputDir, flags.buildpackTOMLOutputPath); err != nil {
		return fmt.Errorf("failed to make commit: %w", err)
	}

	return nil
}

func updateStacks(buildpackTOML helpers.BuildpackTOML, dependencyBuildsConfig dependencyBuildsConfig) (helpers.BuildpackTOML, error) {
	mixinsForStacks, err := getMixinsForStacks(buildpackTOML, dependencyBuildsConfig)
	if err != nil {
		return helpers.BuildpackTOML{}, err
	}

	var sortedStackNames []string
	for stack, _ := range mixinsForStacks {
		sortedStackNames = append(sortedStackNames, stack)
	}
	sort.Strings(sortedStackNames)

	var newStacks []helpers.Stack
	for _, stack := range sortedStackNames {
		newStacks = append(newStacks, helpers.Stack{
			ID:     stack,
			Mixins: mixinsForStacks[stack],
		})
	}
	buildpackTOML.Stacks = newStacks

	return buildpackTOML, nil
}

func getMixinsForStacks(buildpackTOML helpers.BuildpackTOML, dependencyBuildsConfig dependencyBuildsConfig) (map[string][]string, error) {
	var buildpackDependencies []helpers.Dependency
	if err := mapstructure.Decode(buildpackTOML.Metadata[helpers.DependenciesKey], &buildpackDependencies); err != nil {
		return nil, fmt.Errorf("failed to decode dependencies from buildpack.toml: %w", err)
	}

	allMixins := map[string][]string{}
	for _, dependency := range buildpackDependencies {
		dependencyConfig, ok := dependencyBuildsConfig.Dependencies[dependency.ID]
		if !ok {
			return nil, fmt.Errorf("could not find dependency '%s' in dependency-builds config", dependency.ID)
		}

		for _, stack := range dependency.Stacks {
			if _, ok := allMixins[stack]; !ok {
				allMixins[stack] = []string{}
			}

			allMixins[stack] = append(allMixins[stack], dependencyConfig.Mixins[stack]...)
		}
	}

	for stack := range allMixins {
		allMixins[stack] = sortAndUnique(allMixins[stack])
	}

	return allMixins, nil
}

func sortAndUnique(strings []string) []string {
	uniqueStringsMap := map[string]bool{}
	for _, s := range strings {
		uniqueStringsMap[s] = true
	}

	var uniqueStrings []string
	for s, _ := range uniqueStringsMap {
		uniqueStrings = append(uniqueStrings, s)
	}

	sort.Strings(uniqueStrings)
	return uniqueStrings
}

func commitBuildpackTOML(outputDir, buildpackTOMLOutputPath string) error {
	output, err := exec.Command("git", "-C", outputDir, "diff").CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to check for git diff: %w\n%s", err, string(output))
	}

	if string(output) == "" {
		return nil
	}

	output, err = exec.Command("git", "-C", outputDir, "add", buildpackTOMLOutputPath).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to add buildpack.toml: %w:\n%s", err, string(output))
	}

	output, err = exec.Command("git", "-C", outputDir, "commit", "-m", "Update stacks and mixins").CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to commit: %w:\n%s", err, string(output))
	}
	return nil
}
