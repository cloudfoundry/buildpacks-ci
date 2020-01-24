package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"sort"

	"github.com/BurntSushi/toml"

	"github.com/blang/semver"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	"github.com/mitchellh/mapstructure"
	_ "github.com/pkg/errors"
)

var flags struct {
	buildpackTOML    string
	runtimeVersion   string
	outputDir        string
	sdkVersion       string
	releasesJSONPath string
}

type RuntimeToSDK struct {
	RuntimeVersion string   `toml:"runtime-version" mapstructure:"runtime-version"`
	SDKs           []string `toml:"sdks"`
}

type Channel struct {
	Releases      []Release `json:"releases"`
	LatestRuntime string    `json:"latest-runtime"`
}

type Release struct {
	Runtime struct {
		Version string `json:"version"`
	} `json:"runtime,omitempty"`
	Sdk struct {
		Version string `json:"version"`
	} `json:"sdk,omitempty"`
}

func main() {
	flag.StringVar(&flags.buildpackTOML, "buildpack-toml", "", "contents of buildpack.toml")
	flag.StringVar(&flags.runtimeVersion, "runtime-version", "", "runtime version")
	flag.StringVar(&flags.outputDir, "output-dir", "", "directory to write buildpack.toml to")
	flag.StringVar(&flags.sdkVersion, "sdk-version", "", "version of sdk")
	flag.StringVar(&flags.releasesJSONPath, "releases-json-path", "", "path to dotnet releases.json")
	flag.Parse()

	err := updateCompatibilityTable()
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}

func updateCompatibilityTable() error {
	buildpackTOML := helpers.BuildpackTOML{}
	if _, err := toml.Decode(flags.buildpackTOML, &buildpackTOML); err != nil {
		return fmt.Errorf("failed to load buildpack toml: %w", err)
	}

	supported, err := checkIfSupportedPatchVersion()
	if err != nil {
		return err
	}

	versionToRemove := flags.sdkVersion
	if supported {
		versionToRemove, err = addSDKToRuntime(buildpackTOML, flags.sdkVersion, flags.runtimeVersion)
		if err != nil {
			return fmt.Errorf("failed to add sdk to runtime mapping: %w", err)
		}
	} else {
		fmt.Println("this runtime patch version is not supported. only the two latest versions are supported")
	}

	if err := removeUnusedSDK(buildpackTOML, versionToRemove); err != nil {
		return fmt.Errorf("failed to removed unused sdk: %w", err)
	}
	if err := buildpackTOML.WriteToFile(filepath.Join(flags.outputDir, "buildpack.toml")); err != nil {
		return fmt.Errorf("failed to update buildpack toml: %w", err)
	}
	if err := commitArtifacts(flags.sdkVersion, flags.runtimeVersion, flags.outputDir, versionToRemove); err != nil {
		return fmt.Errorf("failed to commit artifacts: %w", err)
	}

	return nil
}

func checkIfSupportedPatchVersion() (bool, error) {
	releasesJSON, err := ioutil.ReadFile(flags.releasesJSONPath)
	if err != nil {
		return false, fmt.Errorf("failed to read releases.json: %w", err)
	}
	var channel Channel
	if err := json.Unmarshal(releasesJSON, &channel); err != nil {
		return false, fmt.Errorf("failed to unmarshal releases.json: %w", err)
	}

	latestRuntime := channel.LatestRuntime
	secondLatestRuntime := ""
	for _, release := range channel.Releases {
		if release.Runtime.Version != latestRuntime {
			secondLatestRuntime = release.Runtime.Version
			break
		}
	}
	return flags.runtimeVersion == latestRuntime || flags.runtimeVersion == secondLatestRuntime, nil
}

func addSDKToRuntime(buildpackTOML helpers.BuildpackTOML, sdkVersion, runtimeVersion string) (string, error) {
	var versionToRemove string
	var inputs []RuntimeToSDK

	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.RuntimeToSDKsKey], &inputs)
	if err != nil {
		return "", err
	}

	runtimeExists := false
	for _, runtimeToSDK := range inputs {
		if runtimeToSDK.RuntimeVersion == runtimeVersion {
			var updatedSDK string
			updatedSDK, versionToRemove, err = checkSDK(sdkVersion, runtimeToSDK.SDKs[0])
			if err != nil {
				return "", err
			}
			runtimeToSDK.SDKs[0] = updatedSDK
			runtimeExists = true
			break
		}
	}

	if !runtimeExists {
		inputs = append(inputs, RuntimeToSDK{
			RuntimeVersion: runtimeVersion,
			SDKs:           []string{sdkVersion},
		})
	}
	sort.Slice(inputs, func(i, j int) bool {
		firstRuntime := semver.MustParse(inputs[i].RuntimeVersion)
		secondRuntime := semver.MustParse(inputs[j].RuntimeVersion)
		return firstRuntime.LT(secondRuntime)
	})

	buildpackTOML.Metadata[helpers.RuntimeToSDKsKey] = inputs
	return versionToRemove, nil
}

func checkSDK(callingSDK, existingSDK string) (string, string, error) {
	var versionToRemove string
	updatedSDK := existingSDK

	currentSdkVersion, err := semver.New(existingSDK)
	if err != nil {
		return "", "", err
	}
	newSdkVersion, err := semver.New(callingSDK)
	if err != nil {
		return "", "", err
	}

	if newSdkVersion.GT(*currentSdkVersion) {
		versionToRemove = existingSDK
		updatedSDK = callingSDK
	} else if newSdkVersion.LT(*currentSdkVersion) {
		versionToRemove = callingSDK
	}
	return updatedSDK, versionToRemove, nil
}

func removeUnusedSDK(buildpackTOML helpers.BuildpackTOML, sdkVersion string) error {
	var dependencies []helpers.Dependency
	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.DependenciesKey], &dependencies)
	if err != nil {
		return err
	}
	for i, dependency := range dependencies {
		if dependency.Version == sdkVersion {
			dependencies = append(dependencies[:i], dependencies[i+1:]...)
			break
		}
	}
	buildpackTOML.Metadata[helpers.DependenciesKey] = dependencies
	return nil
}

func commitArtifacts(sdkVersion, runtimeVersion, outputDir, versionRemoved string) error {
	output, err := exec.Command("git", "-C", outputDir, "diff", "buildpack.toml").CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to get diff of buildpack.toml: %w: %s", err, string(output))
	}
	if string(output) == "" {
		return nil
	}

	var commitMessage string
	if versionRemoved == sdkVersion {
		commitMessage = fmt.Sprintf("Remove sdk %s", sdkVersion)
	} else if versionRemoved == "" {
		commitMessage = fmt.Sprintf("Update compatibility table for sdk %s and runtime %s", sdkVersion, runtimeVersion)
	} else {
		commitMessage = fmt.Sprintf("Update compatibility table for sdk %s and runtime %s\n\n* Remove sdk %s", sdkVersion, runtimeVersion, versionRemoved)
	}

	output, err = exec.Command("git", "-C", outputDir, "add", "buildpack.toml").CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to add artifacts: %w: %s", err, string(output))
	}

	output, err = exec.Command("git", "-C", outputDir, "commit", "-m", commitMessage).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to commit artifacts: %w: %s", err, string(output))
	}
	return nil
}
