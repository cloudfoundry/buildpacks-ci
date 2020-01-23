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
		outputDir    string
		releasesJSON = `{
  "channel-version": "2.1",
  "eol-date": "2099-08-21",
	"latest-runtime": "2.1.15",
  "releases": [
    {
      "release-version": "2.1.15",
      "runtime": { "version": "2.1.15" },
      "sdk": { "version": "2.1.803" },
      "aspnetcore-runtime": { "version": "2.1.15" }
    },
    {
      "release-version": "2.1.14",
      "runtime": { "version": "2.1.14" },
      "sdk": { "version": "2.1.607" },
      "aspnetcore-runtime": { "version": "2.1.14" }
    },
    {
      "release-version": "2.1.802",
      "runtime": { "version": "2.1.13" },
      "sdk": { "version": "2.1.802" },
      "aspnetcore-runtime": { "version": "2.1.13" }
    },
    {
      "release-version": "2.1.13",
      "runtime": { "version": "2.1.13" },
      "sdk": { "version": "2.1.801" },
      "aspnetcore-runtime": { "version": "2.1.13" }
    }
  ]
}`
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
				"--sdk-version", "2.1.803",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.15",
				"--releases-json", releasesJSON,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.15",
					SDKs:           []string{"2.1.803"},
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
    runtime-version = "2.1.14"
    sdks = ["2.1.607"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.803",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.15",
				"--releases-json", releasesJSON,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.14",
					SDKs:           []string{"2.1.607"},
				},
				{
					RuntimeVersion: "2.1.15",
					SDKs:           []string{"2.1.803"},
				},
			}, compatibilityTable)
		})
		it("correctly sorts by runtime version", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := `
  [[metadata.runtime-to-sdks]]
    runtime-version = "2.1.15"
    sdks = ["2.1.607"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.803",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.14",
				"--releases-json", releasesJSON,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.14",
					SDKs:           []string{"2.1.803"},
				},
				{
					RuntimeVersion: "2.1.15",
					SDKs:           []string{"2.1.607"},
				},
			}, compatibilityTable)
		})
		when("the runtime version is not one of the two latest supported versions", func() {
			it("does not add to the compatibility table", func() {
				outputDir = filepath.Join(testdataPath, "artifacts")
				require.NoError(t, os.RemoveAll(outputDir))
				require.NoError(t, os.Mkdir(outputDir, 0755))
				require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

				buildpackTOMLContents := ""

				taskCmd := exec.Command(
					"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
					"--buildpack-toml", buildpackTOMLContents,
					"--sdk-version", "2.1.801",
					"--output-dir", outputDir,
					"--runtime-version", "2.1.13",
					"--releases-json", releasesJSON,
				)
				taskCmd.Env = append(taskCmd.Env, envVars...)

				taskOutput, err := taskCmd.CombinedOutput()
				require.NoError(t, err, string(taskOutput))

				assert.Contains(t, string(taskOutput), "this runtime patch version is not supported. only the two latest versions are supported")
			})
		})
	})

	when("runtime version is present in buildpack.toml", func() {
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
    runtime-version = "2.1.14"
    sdks = ["2.1.606"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.607",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.14",
				"--releases-json", releasesJSON,
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
					RuntimeVersion: "2.1.14",
					SDKs:           []string{"2.1.607"},
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
    runtime-version = "2.1.14"
    sdks = ["2.1.607"]`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.606",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.14",
				"--releases-json", releasesJSON,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

			var compatibilityTable []RuntimeToSDK

			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))

			assert.Equal(t, []RuntimeToSDK{
				{
					RuntimeVersion: "2.1.14",
					SDKs:           []string{"2.1.607"},
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
    sha256 = "505ee870eb9a6a8563d1c94866e80ddf48ee9d10f85277093ec657fd6c012098"
    source = "https://download.visualstudio.microsoft.com/download/pr/39e68289-0364-4173-a12b-c6234e94c527/92f3eb83bfca8b7cd360868996763125/dotnet-sdk-2.1.607-linux-x64.tar.gz"
    source_sha256 = "f38a08584fff6014beb8f6729bcda22040fae40c8bce21a38ec2249823cd173b"
    stacks = ["io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"]
    uri = "https://buildpacks.cloudfoundry.org/dependencies/dotnet-sdk/dotnet-sdk.2.1.607.linux-amd64-cflinuxfs3-505ee870.tar.xz"
    version = "2.1.607"

  [[metadata.dependencies]]
    id = "dotnet-sdk"
    sha256 = "761e82b26e016bc45bf8c90a122b2342f0ec55313e449d1766aa6f16cb4679d3"
    source = "https://download.visualstudio.microsoft.com/download/pr/701502b0-f9a2-464f-9832-4e6ca3126a2a/62655f151db917025e9be8cc4b7c1ed9/dotnet-sdk-2.1.802-linux-x64.tar.gz"
    source_sha256 = "fcb46a4a0c99bf82b591bca2cd276e2d73b65e199f0d14c9cc48dcdf5fb2ffb0"
    stacks = ["io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"]
    uri = "https://buildpacks.cloudfoundry.org/dependencies/dotnet-sdk/dotnet-sdk.2.1.802.linux-amd64-any-stack-761e82b2.tar.xz"
    version = "2.1.802"

  [[metadata.runtime-to-sdks]]
    runtime-version = "2.1.14"
    sdks = ["2.1.607"]

  [[metadata.runtime-to-sdks]]
    runtime-version = "2.1.15"
    sdks = ["2.1.802"]

[[stacks]]
  id = "org.cloudfoundry.stacks.cflinuxfs3"

[[stacks]]
  id = "io.buildpacks.stacks.bionic"
`

		taskCmd := exec.Command(
			"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
			"--buildpack-toml", buildpackTOMLContents,
			"--sdk-version", "2.1.803",
			"--output-dir", outputDir,
			"--runtime-version", "2.1.15",
			"--releases-json", releasesJSON,
		)
		taskCmd.Env = append(taskCmd.Env, envVars...)

		taskOutput, err := taskCmd.CombinedOutput()
		require.NoError(t, err, string(taskOutput))

		outputBuildpackToml, _ := ioutil.ReadFile(filepath.Join(outputDir, "buildpack.toml"))

		expectedBuildpackToml := strings.Replace(buildpackTOMLContents, `["2.1.802"]`, `["2.1.803"]`, 1)

		assert.Equal(t, string(outputBuildpackToml), expectedBuildpackToml)
	})

	when("dotnet runtime is deprecated", func() {
		it("doesn't add to the table", func() {
			outputDir = filepath.Join(testdataPath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			buildpackTOMLContents := ""
			deprecatedReleasesJSON := `{
  "channel-version": "2.1",
  "eol-date": "2000-08-21",
  "releases": [
    {
      "release-version": "2.1.15",
      "runtime": { "version": "2.1.15" },
      "sdk": { "version": "2.1.803" },
      "aspnetcore-runtime": { "version": "2.1.15" }
    }
  ]
}`

			taskCmd := exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-compatibility-table",
				"--buildpack-toml", buildpackTOMLContents,
				"--sdk-version", "2.1.803",
				"--output-dir", outputDir,
				"--runtime-version", "2.1.15",
				"--releases-json", deprecatedReleasesJSON,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			assert.Contains(t, string(taskOutput), "this runtime version is end of life")
		})
	})
}

func decodeBuildpackTOML(t *testing.T, outputDir string) helpers.BuildpackTOML {
	var buildpackTOML helpers.BuildpackTOML
	_, err := toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackTOML)
	require.NoError(t, err)
	return buildpackTOML
}
