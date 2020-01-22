package main_test

import (
	"flag"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/BurntSushi/toml"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table"
	"github.com/mitchellh/mapstructure"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var update = flag.Bool("update", false, "updates golden files")

func TestUpdateCNBDependencyTask(t *testing.T) {
	spec.Run(t, "UpdateCNBDependencyTask", testUpdateCNBDependencyTask, spec.Report(report.Terminal{}))
}

func testUpdateCNBDependencyTask(t *testing.T, when spec.G, it spec.S) {
	var (
		testdataPath = "testdata"
		envVars      = []string{
			"HOME=" + os.Getenv("HOME"),
			"PATH=" + os.Getenv("PATH"),
		}
		outputDir string
	)
	when("with empty buildpack.toml", func() {
		it("add version of sdk dependency", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := `
[metadata]
`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.102",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.1",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.1",
					SDKs:           []string{"2.1.102"},
				},
			}, compatibilityTable)

		})
	})

	when("with runtime version doesn't exist in buildpack.toml", func() {
		it("add version of sdk dependency", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := `
  [[metadata.runtime-to-sdks]]
    runtime-version = "2.1.12"
    sdks = ["2.1.801"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.802",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.13",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.12",
					SDKs:           []string{"2.1.801"},
				},
				{
					RuntimeVersion: "2.1.13",
					SDKs:           []string{"2.1.802"},
				},
			}, compatibilityTable)
		})
	})

	when("with runtime version present in buildpack.toml", func() {
		it("include only one latest version of sdk dependency", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := `
  [[metadata.runtime-to-sdks]]
    runtime-version = "1.1.13"
    sdks = ["1.1.801"]
	[[metadata.runtime-to-sdks]]
    runtime-version = "2.1.13"
    sdks = ["2.1.801"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.906",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.13",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK

			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "1.1.13",
					SDKs:           []string{"1.1.801"},
				},
				{
					RuntimeVersion: "2.1.13",
					SDKs:           []string{"2.1.906"},
				},
			}, compatibilityTable)

		})
	})

	when("dotnet runtime already has latest sdk depedency", func() {
		it("includes the existing sdk dependency and ignores given new dependency", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := `
  [[metadata.runtime-to-sdks]]
    runtime-version = "2.1.13"
    sdks = ["2.1.801"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.606",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.13",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK

			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.13",
					SDKs:           []string{"2.1.801"},
				},
			}, compatibilityTable)
		})
	})

	it("should keep the integrity of the rest of the toml", func() {
		outputDir = filepath.Join(testdataPath, "artifacts")
		require.NoError(t, os.RemoveAll(outputDir))
		require.NoError(t, os.Mkdir(outputDir, 0755))
		require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

		buildpackTOMLContents := `api = "0.2"

[buildpack]
  id = "org.cloudfoundry.dotnet-core-sdk"
  name = ".NET SDK Buildpack"
  version = "{{ .Version }}"

[metadata]
  include_files = ["bin/build", "bin/detect", "buildpack.toml", "go.mod", "go.sum"]
  pre_package = "./scripts/build.sh"

  [[metadata.dependencies]]
    id = "dotnet-sdk"
    sha256 = "2f4cbb9d93e79fcd330d81bde9fa471e33e3ed7a7b8cf57c897d9ca8588a8160"
    source = "https://download.visualstudio.microsoft.com/download/pr/d731f991-8e68-4c7c-8ea0-fad5605b077a/49497b5420eecbd905158d86d738af64/dotnet-sdk-3.1.100-linux-x64.tar.gz"
    source_sha256 = "3687b2a150cd5fef6d60a4693b4166994f32499c507cd04f346b6dda38ecdc46"
    stacks = ["io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"]
    uri = "https://buildpacks.cloudfoundry.org/dependencies/dotnet-sdk/dotnet-sdk.3.1.100.linux-amd64-any-stack-2f4cbb9d.tar.xz"
    version = "3.1.100"

  [[metadata.dependencies]]
    id = "dotnet-sdk"
    sha256 = "670669f5823be815cd278ec11621ce00ca671027bc6038d665516bb6b14c871b"
    source = "https://download.visualstudio.microsoft.com/download/pr/c4b503d6-2f41-4908-b634-270a0a1dcfca/c5a20e42868a48a2cd1ae27cf038044c/dotnet-sdk-3.1.101-linux-x64.tar.gz"
    source_sha256 = "a1060891482267f4b36a877b547396d7838bc36c65ef16db192344fd9b29211d"
    stacks = ["io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"]
    uri = "https://buildpacks.cloudfoundry.org/dependencies/dotnet-sdk/dotnet-sdk.3.1.101.linux-amd64-any-stack-670669f5.tar.xz"
    version = "3.1.101"

  [[metadata.runtime-to-sdks]]
    runtime-version = "3.1.0"
    sdks = ["3.1.100"]

  [[metadata.runtime-to-sdks]]
    runtime-version = "3.1.1"
    sdks = ["3.1.101"]

[[stacks]]
  id = "org.cloudfoundry.stacks.cflinuxfs3"

[[stacks]]
  id = "io.buildpacks.stacks.bionic"
`

		taskCmd := exec.Command(
			"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
			"--buildpack-toml", buildpackTOMLContents,
			"--sdk-version", "3.1.201",
			"--output-dir", outputDir,
			"--runtime-version", "3.1.1",
		)
		taskCmd.Env = append(taskCmd.Env, envVars...)

		taskOutput, err := taskCmd.CombinedOutput()
		require.NoError(t, err, string(taskOutput))

		outputBuildpackToml, _ := ioutil.ReadFile(filepath.Join(outputDir, "buildpack.toml"))

		expectedBuildpackToml := strings.Replace(buildpackTOMLContents, `["3.1.101"]`, `["3.1.201"]`, 1)

		assert.Equal(t, expectedBuildpackToml, string(outputBuildpackToml))
	})
}

func decodeBuildpackTOML(t *testing.T, outputDir string) helpers.BuildpackTOML {
	var buildpackTOML helpers.BuildpackTOML
	_, err := toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackTOML)
	require.NoError(t, err)
	return buildpackTOML
}
