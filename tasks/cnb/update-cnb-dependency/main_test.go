package main_test

import (
	"flag"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency"
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
		taskCmd *exec.Cmd
		envVars = []string{
			"HOME=" + os.Getenv("HOME"),
			"PATH=" + os.Getenv("PATH"),
		}
		outputDir string
	)

	it.After(func() {
		goldenPath := filepath.Join(filepath.Dir(outputDir), "golden_buildpack.toml")
		actualBuildpackTOML, err := ioutil.ReadFile(filepath.Join(outputDir, "buildpack.toml"))
		require.NoError(t, err)

		if *update {
			require.NoError(t, ioutil.WriteFile(goldenPath, actualBuildpackTOML, 0644))
		}

		expectedGoldenFile, err := ioutil.ReadFile(goldenPath)
		require.NoError(t, err)

		assert.Equal(t, string(expectedGoldenFile), string(actualBuildpackTOML))
		require.NoError(t, os.RemoveAll(outputDir))
	})

	when("updating a child CNB", func() {
		var (
			basePath         = "testdata/updating-child-cnb"
			binaryBuildsPath = filepath.Join(basePath, "binary-builds")
			versionLine      = "2.X.X"
			versionsToKeep   = "2"
			deprecationDate  = "2040-01-01"
			deprecationLink  = "some-updated-deprecation-link"
		)

		it.Before(func() {
			outputDir = filepath.Join(basePath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			dependencyBuildsConfig, err := ioutil.ReadFile(filepath.Join(basePath, "dependency-builds.yml"))
			require.NoError(t, err)

			sourceBuildpackTOML, err := ioutil.ReadFile(filepath.Join(basePath, "buildpack.toml"))
			require.NoError(t, err)

			sourceData, err := ioutil.ReadFile(filepath.Join(basePath, "data.json"))
			require.NoError(t, err)

			taskCmd = exec.Command(
				"go", "run", "-mod=vendor", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency",
				"--dependency-builds-config", string(dependencyBuildsConfig),
				"--buildpack-toml", string(sourceBuildpackTOML),
				"--source-data", string(sourceData),
				"--binary-builds-path", binaryBuildsPath,
				"--output-dir", outputDir,
				"--buildpack-toml-output-path", "buildpack.toml",
				"--version-line", versionLine,
				"--versions-to-keep", versionsToKeep,
				"--deprecation-date", deprecationDate,
				"--deprecation-link", deprecationLink,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))
		})

		it("updates the dep in the buildpack.toml deps and retains existing arbitrary metadata", func() {
			buildpackTOML := decodeBuildpackTOML(t, outputDir)
			assert.Equal(t, "./scripts/build.sh", buildpackTOML.Metadata[helpers.PrePackageKey])
			assert.Equal(t, "random", buildpackTOML.Metadata["random"])
			assert.Equal(t, []interface{}{"bin/build", "bin/detect", "buildpack.toml"}, buildpackTOML.Metadata[helpers.IncludeFilesKey])
			assert.Equal(t, map[string]interface{}{
				"some-dep": "2.x",
			}, buildpackTOML.Metadata[helpers.DefaultVersionsKey])

			var deps Dependencies
			require.NoError(t, mapstructure.Decode(buildpackTOML.Metadata["dependencies"], &deps))
			deprecationDate2020 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC).Format(time.RFC3339)
			deprecationDate2030 := time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC).Format(time.RFC3339)
			deprecationDate2040 := time.Date(2040, 1, 1, 0, 0, 0, 0, time.UTC).Format(time.RFC3339)
			assert.Equal(t, Dependencies{
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-bionic-binary-1.0.0",
					Stacks:          []string{"io.buildpacks.stacks.bionic"},
					URI:             "https://example.org/some-dep-1.0.0.tgz",
					Version:         "1.0.0",
					DeprecationDate: deprecationDate2020,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-cflinuxfs3-binary-1.0.0",
					Source:          "https://example.org/some-dep-1.0.0-source.tgz",
					SourceSHA256:    "sha256-for-source-1.0.0",
					Stacks:          []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:             "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-1.0.0.linux-amd64-cflinuxfs3-aaaaaaaa.tar.gz",
					Version:         "1.0.0",
					DeprecationDate: deprecationDate2020,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-bionic-binary-1.0.1",
					Stacks:          []string{"io.buildpacks.stacks.bionic"},
					URI:             "https://example.org/some-dep-1.0.1.tgz",
					Version:         "1.0.1",
					DeprecationDate: deprecationDate2020,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-cflinuxfs3-binary-1.0.1",
					Source:          "https://example.org/some-dep-1.0.1-source.tgz",
					SourceSHA256:    "sha256-for-source-1.0.1",
					Stacks:          []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:             "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-1.0.1.linux-amd64-cflinuxfs3-bbbbbbbb.tar.gz",
					Version:         "1.0.1",
					DeprecationDate: deprecationDate2020,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-bionic-binary-2.0.1",
					Stacks:          []string{"io.buildpacks.stacks.bionic"},
					URI:             "https://example.org/some-dep-2.0.1.tgz",
					Version:         "2.0.1",
					DeprecationDate: deprecationDate2030,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-cflinuxfs3-binary-2.0.1",
					Source:          "https://example.org/some-dep-2.0.1-source.tgz",
					SourceSHA256:    "sha256-for-source-2.0.1",
					Stacks:          []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:             "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-2.0.1.linux-amd64-cflinuxfs3-dddddddd.tar.gz",
					Version:         "2.0.1",
					DeprecationDate: deprecationDate2030,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-cflinuxfs3-binary-2.1.0",
					Source:          "https://example.org/some-dep-2.1.0-source.tgz",
					SourceSHA256:    "sha256-for-source-2.1.0",
					Stacks:          []string{"io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"},
					URI:             "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-2.1.0.linux-amd64-cflinuxfs3-eeeeeeee.tar.gz",
					Version:         "2.1.0",
					DeprecationDate: deprecationDate2040,
				},
				{
					ID:              "some-dep",
					Name:            "Some Dep",
					SHA256:          "sha256-for-tiny-binary-2.1.0",
					Stacks:          []string{"org.cloudfoundry.stacks.tiny"},
					URI:             "https://example.org/some-dep-2.1.0.tgz",
					Version:         "2.1.0",
					DeprecationDate: deprecationDate2040,
				},
			}, deps)
		})

		it("shows the added and removed dep versions in the commit message", func() {
			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Add some-dep 2.1.0, remove some-dep 2.0.0")
			assert.Contains(t, string(latestCommitMessage), "for stack(s) io.buildpacks.stacks.bionic, org.cloudfoundry.stacks.cflinuxfs3, org.cloudfoundry.stacks.tiny [#111111111]")
		})
	})

	when("updating a parent CNB", func() {
		var (
			basePath         = "testdata/updating-parent-cnb/"
			binaryBuildsPath = filepath.Join(basePath, "binary-builds")
			versionLine      = "latest"
			versionsToKeep   = "1"
		)

		it.Before(func() {
			outputDir = filepath.Join(basePath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			dependencyBuildsConfig, err := ioutil.ReadFile(filepath.Join(basePath, "dependency-builds.yml"))
			require.NoError(t, err)

			buildpackTOML, err := ioutil.ReadFile(filepath.Join(basePath, "buildpack.toml"))
			require.NoError(t, err)

			sourceData, err := ioutil.ReadFile(filepath.Join(basePath, "data.json"))
			require.NoError(t, err)

			taskCmd = exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency",
				"--dependency-builds-config", string(dependencyBuildsConfig),
				"--buildpack-toml", string(buildpackTOML),
				"--source-data", string(sourceData),
				"--binary-builds-path", binaryBuildsPath,
				"--output-dir", outputDir,
				"--buildpack-toml-output-path", "buildpack.toml",
				"--version-line", versionLine,
				"--versions-to-keep", versionsToKeep,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)
			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))
		})

		it("updates the child CNB in the buildpack.toml deps", func() {
			buildpackTOML := decodeBuildpackTOML(t, outputDir)

			var deps Dependencies
			require.NoError(t, mapstructure.Decode(buildpackTOML.Metadata["dependencies"], &deps))
			assert.Equal(t, Dependencies{
				{
					ID:           "org.cloudfoundry.some-child",
					SHA256:       "sha256-for-binary-1.0.1",
					Source:       "https://github.com/cloudfoundry/some-child-cnb/archive/v1.0.1.tar.gz",
					SourceSHA256: "sha256-for-source-1.0.1",
					Stacks:       []string{"io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/org.cloudfoundry.some-child/org.cloudfoundry.some-child-1.0.1-any-stack-bbbbbbbb.tgz",
					Version:      "1.0.1",
				},
			}, deps)
		})

		it("updates versions in order", func() {
			buildpackTOML := decodeBuildpackTOML(t, outputDir)

			assert.Equal(t, []helpers.Order{{Group: []helpers.Group{
				{
					ID:       "org.cloudfoundry.some-child",
					Version:  "1.0.1",
					Optional: true,
				},
				{
					ID:      "org.cloudfoundry.other-child",
					Version: "2.0.0",
				},
			}}}, buildpackTOML.Orders)
		})

		it("shows the added and removed child CNB versions in the commit message", func() {
			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Add org.cloudfoundry.some-child 1.0.1, remove org.cloudfoundry.some-child 1.0.0")
			assert.Contains(t, string(latestCommitMessage), "for stack(s) io.buildpacks.stacks.bionic, org.cloudfoundry.stacks.cflinuxfs3 [#111111111]")
		})
	})

	when("updating a parent CNB with tiny included", func() {
		var (
			basePath         = "testdata/updating-parent-cnb-with-tiny-stack"
			binaryBuildsPath = filepath.Join(basePath, "binary-builds")
			versionLine      = "latest"
			versionsToKeep   = "1"
		)

		it.Before(func() {
			outputDir = filepath.Join(basePath, "artifacts")
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())

			dependencyBuildsConfig, err := ioutil.ReadFile(filepath.Join(basePath, "dependency-builds.yml"))
			require.NoError(t, err)

			buildpackTOML, err := ioutil.ReadFile(filepath.Join(basePath, "buildpack.toml"))
			require.NoError(t, err)

			sourceData, err := ioutil.ReadFile(filepath.Join(basePath, "data.json"))
			require.NoError(t, err)

			taskCmd = exec.Command(
				"go", "run", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency",
				"--dependency-builds-config", string(dependencyBuildsConfig),
				"--buildpack-toml", string(buildpackTOML),
				"--source-data", string(sourceData),
				"--binary-builds-path", binaryBuildsPath,
				"--output-dir", outputDir,
				"--buildpack-toml-output-path", "buildpack.toml",
				"--version-line", versionLine,
				"--versions-to-keep", versionsToKeep,
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)
			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))
		})

		it("includes tiny stack in dependencies and commit message", func() {
			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Add org.cloudfoundry.some-child 1.0.1, remove org.cloudfoundry.some-child 1.0.0")
			assert.Contains(t, string(latestCommitMessage), "for stack(s) io.buildpacks.stacks.bionic, org.cloudfoundry.stacks.cflinuxfs3, org.cloudfoundry.stacks.tiny [#111111111]")

			var buildpackTOML helpers.BuildpackTOML
			_, err = toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackTOML)
			require.NoError(t, err)

			var deps Dependencies
			require.NoError(t, mapstructure.Decode(buildpackTOML.Metadata["dependencies"], &deps))
			assert.Equal(t, Dependencies{
				{
					ID:           "org.cloudfoundry.some-child",
					SHA256:       "sha256-for-binary-1.0.1",
					Source:       "https://github.com/cloudfoundry/some-child-cnb/archive/v1.0.1.tar.gz",
					SourceSHA256: "sha256-for-source-1.0.1",
					Stacks:       []string{"io.buildpacks.stacks.bionic", "org.cloudfoundry.stacks.cflinuxfs3", "org.cloudfoundry.stacks.tiny"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/org.cloudfoundry.some-child/org.cloudfoundry.some-child-1.0.1-any-stack-bbbbbbbb.tgz",
					Version:      "1.0.1",
				},
			}, deps)
		})
	})
}

func decodeBuildpackTOML(t *testing.T, outputDir string) helpers.BuildpackTOML {
	var buildpackTOML helpers.BuildpackTOML
	_, err := toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackTOML)
	require.NoError(t, err)
	return buildpackTOML
}
