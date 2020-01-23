package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"time"

	"github.com/BurntSushi/toml"

	"github.com/pkg/errors"

	"github.com/blang/semver"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	"github.com/mitchellh/mapstructure"
	_ "github.com/pkg/errors"
)

var flags struct {
	buildpackTOML  string
	runtimeVersion string
	outputDir      string
	sdkVersion     string
	releasesJSON   string
}

type RuntimeToSDK struct {
	RuntimeVersion string   `toml:"runtime-version" mapstructure:"runtime-version"`
	SDKs           []string `toml:"sdks"`
}

type Channel struct {
	Releases      []Release `json:"releases"`
	EOLDate       string    `json:"eol-date"`
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
	flag.StringVar(&flags.releasesJSON, "releases-json", "", "contents of dotnet releases.json")
	flag.Parse()

	message, err := checkIfSupported()
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	if message != "" {
		fmt.Println(message)
		os.Exit(0)
	}

	err = updateCompatibilityTable()
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

	updated, err := addSDKToRuntime(buildpackTOML, flags.sdkVersion, flags.runtimeVersion)
	if err != nil {
		return fmt.Errorf("failed to add sdk to runtime mapping: %w", err)
	}

	if err := buildpackTOML.WriteToFile(filepath.Join(flags.outputDir, "buildpack.toml")); err != nil {
		return fmt.Errorf("failed to update buildpack toml: %w", err)
	}

	if updated {
		if err := commitArtifacts(flags.sdkVersion, flags.runtimeVersion, flags.outputDir); err != nil {
			return fmt.Errorf("failed to commit artifacts: %w", err)
		}
	}
	return nil
}

func addSDKToRuntime(buildpackTOML helpers.BuildpackTOML, sdkVersion, runtimeVersion string) (bool, error) {
	updated := false
	var inputs []RuntimeToSDK

	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.RuntimeToSDKsKey], &inputs)
	if err != nil {
		return false, err
	}

	runtimeExists := false
	for _, runtimeToSDK := range inputs {
		if runtimeToSDK.RuntimeVersion == runtimeVersion {
			currentSdkVersion, err := semver.New(runtimeToSDK.SDKs[0])
			if err != nil {
				return false, err
			}
			newSdkVersion, err := semver.New(sdkVersion)
			if err != nil {
				return false, err
			}
			if newSdkVersion.GT(*currentSdkVersion) == true {
				updated = true
				runtimeToSDK.SDKs[0] = sdkVersion
			}
			runtimeExists = true
			break
		}
	}

	if !runtimeExists {
		updated = true
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

	if updated {
		buildpackTOML.Metadata[helpers.RuntimeToSDKsKey] = inputs
	}
	return updated, nil
}

func commitArtifacts(sdkVersion, runtimeVersion, outputDir string) error {
	commitMessage := fmt.Sprintf("Update compatibility matrix for sdk %s and runtime %s", sdkVersion, runtimeVersion)

	output, err := exec.Command("git", "-C", outputDir, "add", "buildpack.toml").CombinedOutput()
	if err != nil {
		return errors.Wrapf(err, "failed to add artifacts: %s", string(output))
	}

	output, err = exec.Command("git", "-C", outputDir, "commit", "-m", commitMessage).CombinedOutput()
	if err != nil {
		return errors.Wrapf(err, "failed to commit artifacts: %s", string(output))
	}
	return nil
}

func checkIfSupported() (string, error) {
	var channel Channel
	if err := json.Unmarshal([]byte(flags.releasesJSON), &channel); err != nil {
		return "", fmt.Errorf("failed to unmarshal releases.json: %w", err)
	}

	eol, err := checkIfEol(channel)
	if err != nil {
		return "", fmt.Errorf("failed to get eol date: %w", err)
	}
	if eol {
		return "this runtime version is end of life", nil
	}

	if !checkIfSupportedPatchVersion(channel, flags.runtimeVersion) {
		return "this runtime patch version is not supported. only the two latest versions are supported", nil
	}
	return "", nil
}

func checkIfEol(channel Channel) (bool, error) {
	eolDate, err := time.Parse("2006-01-02", channel.EOLDate)
	if err != nil {
		return false, err
	}

	return eolDate.Before(time.Now()), nil
}

func checkIfSupportedPatchVersion(channel Channel, version string) bool {
	latestRuntime := channel.LatestRuntime
	secondLatestRuntime := ""
	for _, release := range channel.Releases {
		if release.Runtime.Version != latestRuntime {
			secondLatestRuntime = release.Runtime.Version
			break
		}
	}
	return version == latestRuntime || version == secondLatestRuntime
}
