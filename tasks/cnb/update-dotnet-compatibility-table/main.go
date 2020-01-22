package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/pkg/errors"

	"github.com/BurntSushi/toml"
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
}

type RuntimeToSDK struct {
	RuntimeVersion string   `toml:"runtime-version" mapstructure:"runtime-version"`
	SDKs           []string `toml:"sdks"`
}

func main() {
	flag.StringVar(&flags.buildpackTOML, "buildpack-toml", "", "contents of buildpack.toml")
	flag.StringVar(&flags.runtimeVersion, "runtime-version", "", "runtime version")
	flag.StringVar(&flags.outputDir, "output-dir", "", "directory to write buildpack.toml to")
	flag.StringVar(&flags.sdkVersion, "sdk-version", "", "version of sdk")
	flag.Parse()

	buildpackTOML := helpers.BuildpackTOML{}

	if _, err := toml.Decode(flags.buildpackTOML, &buildpackTOML); err != nil {
		fmt.Println("failed to load buildpack toml", err)
		os.Exit(1)
	}

	updated, err := AddSDKToRuntime(buildpackTOML, flags.sdkVersion, flags.runtimeVersion)
	if err != nil {
		fmt.Println("failed to add sdk to runtime mapping", err)
		os.Exit(1)
	}

	if err := buildpackTOML.WriteToFile(filepath.Join(flags.outputDir, "buildpack.toml")); err != nil {
		fmt.Println("failed to update buildpack toml", err)
		os.Exit(1)
	}

	if updated {
		if err := CommitArtifacts(flags.sdkVersion, flags.runtimeVersion, flags.outputDir); err != nil {
			fmt.Println("failed to commit artifacts", err)
			os.Exit(1)
		}
	}
}

func AddSDKToRuntime(buildpackTOML helpers.BuildpackTOML, sdkVersion, runtimeVersion string) (bool, error) {
	updated := false
	var inputs []RuntimeToSDK

	err := mapstructure.Decode(buildpackTOML.Metadata[helpers.RuntimeToSDKsKey], &inputs)
	if err != nil {
		return false, err
	}

	runtimeExists := false
	for _, runtimeToSDK := range inputs {
		if runtimeToSDK.RuntimeVersion == runtimeVersion {
			currentSdkVersion, _ := semver.New(runtimeToSDK.SDKs[0])
			newSdkVersion, _ := semver.New(sdkVersion)
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

	buildpackTOML.Metadata[helpers.RuntimeToSDKsKey] = inputs
	return updated, nil
}

func CommitArtifacts(sdkVersion, runtimeVersion, outputDir string) error {
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
