package main_test

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/BurntSushi/toml"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-sdks-and-compat-table"
	"github.com/mitchellh/mapstructure"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpdateCNBDependencyTask(t *testing.T) {
	spec.Run(t, "UpdateCNBDependencyTask", testUpdateCNBDependencyTask, spec.Report(report.Terminal{}))
}

func testUpdateCNBDependencyTask(t *testing.T, when spec.G, it spec.S) {
	var (
		outputDir    = filepath.Join("testdata", "artifacts")
		releasesJSON = filepath.Join("testdata", "releases.json")
	)
	when("with empty buildpack.toml", func() {
		it("add version of sdk dependency", func() {
			buildpackTOML := helpers.BuildpackTOML{Metadata: helpers.Metadata{}}

			runTask(t, buildpackTOML, releasesJSON, "2.1.803", "2.1.15", outputDir)

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
			buildpackTOML := helpers.BuildpackTOML{
				Metadata: helpers.Metadata{
					helpers.RuntimeToSDKsKey: []RuntimeToSDK{
						{RuntimeVersion: "2.1.14", SDKs: []string{"2.1.607"}},
					},
				},
			}

			runTask(t, buildpackTOML, releasesJSON, "2.1.803", "2.1.15", outputDir)

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
			buildpackTOML := helpers.BuildpackTOML{
				Metadata: helpers.Metadata{
					helpers.RuntimeToSDKsKey: []RuntimeToSDK{
						{RuntimeVersion: "2.1.15", SDKs: []string{"2.1.607"}},
					},
				},
			}

			runTask(t, buildpackTOML, releasesJSON, "2.1.803", "2.1.14", outputDir)

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

			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Update compatibility table for sdk 2.1.803 and runtime 2.1.14")
			assert.NotContains(t, string(latestCommitMessage), "Remove")
		})

		when("the runtime version is not one of the two latest supported versions", func() {
			it("does not add to the compatibility table", func() {
				buildpackTOML := helpers.BuildpackTOML{
					Metadata: helpers.Metadata{
						helpers.DependenciesKey: []helpers.Dependency{
							{ID: "dotnet-sdk", Version: "2.1.801"},
						},
					},
				}

				taskOutput := runTask(t, buildpackTOML, releasesJSON, "2.1.801", "2.1.13", outputDir)

				assert.Contains(t, taskOutput, "this runtime patch version is not supported. only the two latest versions are supported")

				outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

				var dependencies []helpers.Dependency
				require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["dependencies"], &dependencies))
				assert.Empty(t, dependencies)
			})
		})
	})

	when("runtime version is present in buildpack.toml", func() {
		it("include only one latest version of sdk dependency", func() {
			buildpackTOML := helpers.BuildpackTOML{
				Metadata: helpers.Metadata{
					helpers.DependenciesKey: []helpers.Dependency{
						{ID: "dotnet-sdk", Version: "1.1.801"},
						{ID: "dotnet-sdk", Version: "2.1.606"},
						{ID: "dotnet-sdk", Version: "2.1.607"},
					},
					helpers.RuntimeToSDKsKey: []RuntimeToSDK{
						{RuntimeVersion: "1.1.13", SDKs: []string{"1.1.801"}},
						{RuntimeVersion: "2.1.14", SDKs: []string{"2.1.606"}},
					},
				},
			}

			runTask(t, buildpackTOML, releasesJSON, "2.1.607", "2.1.14", outputDir)

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

			var dependencies []helpers.Dependency
			require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["dependencies"], &dependencies))
			assert.Equal(t, []helpers.Dependency{
				{ID: "dotnet-sdk", Version: "1.1.801"},
				{ID: "dotnet-sdk", Version: "2.1.607"},
			}, dependencies)

			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Update compatibility table for sdk 2.1.607 and runtime 2.1.14")
			assert.Contains(t, string(latestCommitMessage), "* Remove sdk 2.1.606")
		})
	})

	when("dotnet runtime already has latest sdk depedency", func() {
		when("the sdk is not the latest version", func() {
			it("includes the existing sdk dependency and ignores given new dependency", func() {
				buildpackTOML := helpers.BuildpackTOML{
					Metadata: helpers.Metadata{
						helpers.DependenciesKey: []helpers.Dependency{
							{ID: "dotnet-sdk", Version: "2.1.606"},
							{ID: "dotnet-sdk", Version: "2.1.607"},
						},
						helpers.RuntimeToSDKsKey: []RuntimeToSDK{
							{RuntimeVersion: "2.1.14", SDKs: []string{"2.1.607"}},
						},
					},
				}

				runTask(t, buildpackTOML, releasesJSON, "2.1.606", "2.1.14", outputDir)

				outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

				var compatibilityTable []RuntimeToSDK
				require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))
				assert.Equal(t, []RuntimeToSDK{
					{
						RuntimeVersion: "2.1.14",
						SDKs:           []string{"2.1.607"},
					},
				}, compatibilityTable)

				var dependencies []helpers.Dependency
				require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["dependencies"], &dependencies))
				assert.Equal(t, []helpers.Dependency{
					{ID: "dotnet-sdk", Version: "2.1.607"},
				}, dependencies)

				cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
				latestCommitMessage, err := cmd.CombinedOutput()
				require.NoError(t, err, string(latestCommitMessage))
				assert.Contains(t, string(latestCommitMessage), "Remove sdk 2.1.606")
				assert.NotContains(t, string(latestCommitMessage), "Update")
			})
		})

		when("the sdk is the latest version", func() {
			it("does not update or remove from buildpack.toml", func() {
				buildpackTOML := helpers.BuildpackTOML{
					Metadata: helpers.Metadata{
						helpers.DependenciesKey: []helpers.Dependency{
							{ID: "dotnet-sdk", Version: "2.1.607"},
						},
						helpers.RuntimeToSDKsKey: []RuntimeToSDK{
							{RuntimeVersion: "2.1.14", SDKs: []string{"2.1.607"}},
						},
					},
				}

				runTask(t, buildpackTOML, releasesJSON, "2.1.607", "2.1.14", outputDir)

				outputBuildpackToml := decodeBuildpackTOML(t, outputDir)

				var compatibilityTable []RuntimeToSDK
				require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["runtime-to-sdks"], &compatibilityTable))
				assert.Equal(t, []RuntimeToSDK{
					{
						RuntimeVersion: "2.1.14",
						SDKs:           []string{"2.1.607"},
					},
				}, compatibilityTable)

				var dependencies []helpers.Dependency
				require.NoError(t, mapstructure.Decode(outputBuildpackToml.Metadata["dependencies"], &dependencies))
				assert.Equal(t, []helpers.Dependency{
					{ID: "dotnet-sdk", Version: "2.1.607"},
				}, dependencies)

				cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
				latestCommitMessage, err := cmd.CombinedOutput()
				require.NoError(t, err, string(latestCommitMessage))
				assert.Contains(t, string(latestCommitMessage), "Initial commit")
			})
		})
	})

	it("should keep the integrity of the rest of the toml", func() {
		buildpackTOML := helpers.BuildpackTOML{
			API: "0.2",
			Metadata: helpers.Metadata{
				helpers.IncludeFilesKey: []string{"bin/build", "bin/detect", "buildpack.toml", "go.mod", "go.sum"},
				helpers.PrePackageKey:   "./scripts/build.sh",
				helpers.DependenciesKey: []helpers.Dependency{
					{ID: "dotnet-sdk", Version: "2.1.607"},
					{ID: "dotnet-sdk", Version: "2.1.802"},
					{ID: "dotnet-sdk", Version: "2.1.803"},
				},
				helpers.RuntimeToSDKsKey: []RuntimeToSDK{
					{RuntimeVersion: "2.1.14", SDKs: []string{"2.1.607"}},
					{RuntimeVersion: "2.1.15", SDKs: []string{"2.1.802"}},
				},
			},
			Stacks: []helpers.Stack{
				{ID: "org.cloudfoundry.stacks.cflinuxfs3"},
				{ID: "io.buildpacks.stacks.bionic"},
			},
		}

		runTask(t, buildpackTOML, releasesJSON, "2.1.803", "2.1.15", outputDir)

		outputBuildpackToml := decodeBuildpackTOML(t, outputDir)
		assert.Equal(t, "0.2", outputBuildpackToml.API)
		assert.Equal(t, "./scripts/build.sh", outputBuildpackToml.Metadata[helpers.PrePackageKey])
		assert.Len(t, outputBuildpackToml.Stacks, 2)
	})
}

func decodeBuildpackTOML(t *testing.T, outputDir string) helpers.BuildpackTOML {
	var buildpackTOML helpers.BuildpackTOML
	_, err := toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackTOML)
	require.NoError(t, err)
	return buildpackTOML
}

func runTask(t *testing.T, buildpackTOML helpers.BuildpackTOML, releasesJSON, sdkVersion, runtimeVersion, outputDir string) string {
	buildpackTOMLContents := setupOutputDirectory(t, outputDir, buildpackTOML)

	taskCmd := exec.Command(
		"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-dotnet-sdks-and-compat-table",
		"--buildpack-toml", buildpackTOMLContents,
		"--releases-json-path", releasesJSON,
		"--sdk-version", sdkVersion,
		"--runtime-version", runtimeVersion,
		"--output-dir", outputDir,
	)
	taskCmd.Env = append(taskCmd.Env, "HOME="+os.Getenv("HOME"), "PATH="+os.Getenv("PATH"))

	taskOutput, err := taskCmd.CombinedOutput()
	require.NoError(t, err, string(taskOutput))
	return string(taskOutput)
}

func setupOutputDirectory(t *testing.T, outputDir string, buildpackTOML helpers.BuildpackTOML) string {
	require.NoError(t, os.RemoveAll(outputDir))
	require.NoError(t, os.Mkdir(outputDir, 0755))
	require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())
	require.NoError(t, buildpackTOML.WriteToFile(filepath.Join(outputDir, "buildpack.toml")))
	require.NoError(t, exec.Command("git", "-C", outputDir, "add", "buildpack.toml").Run())
	require.NoError(t, exec.Command("git", "-C", outputDir, "commit", "-m", "Initial commit").Run())

	buildpackTOMLContents, err := ioutil.ReadFile(filepath.Join(outputDir, "buildpack.toml"))
	require.NoError(t, err)
	return string(buildpackTOMLContents)
}
