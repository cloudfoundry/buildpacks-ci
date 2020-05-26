package main_test

import (
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestUpdateStacksTask(t *testing.T) {
	spec.Run(t, "UpdateStacksTask", testUpdateStacksTask, spec.Report(report.Terminal{}))
}

func testUpdateStacksTask(t *testing.T, when spec.G, it spec.S) {
	var (
		taskCmd *exec.Cmd
		envVars = []string{
			"HOME=" + os.Getenv("HOME"),
			"PATH=" + os.Getenv("PATH"),
		}
		outputDir string
	)

	it.Before(func() {
		var err error
		outputDir, err = ioutil.TempDir("", "update-stacks-task")
		require.NoError(t, err)
		require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())
	})

	it.After(func() {
		require.NoError(t, os.RemoveAll(outputDir))
	})

	when("there are changes in buildpack.toml", func() {
		it.Before(func() {
			originalBuildpackTOML, err := ioutil.ReadFile(filepath.Join("testdata", "original-buildpack.toml"))
			require.NoError(t, err)

			err = ioutil.WriteFile(filepath.Join(outputDir, "buildpack.toml"), originalBuildpackTOML, 0644)
			require.NoError(t, err)

			require.NoError(t, exec.Command("git", "-C", outputDir, "add", "buildpack.toml").Run())
			require.NoError(t, exec.Command("git", "-C", outputDir, "commit", "-m", "initial commit").Run())
		})

		it("updates the stacks and mixins in buildpack.toml", func() {
			dependencyBuildsConfig, err := ioutil.ReadFile(filepath.Join("testdata", "dependency-builds-config.yml"))
			require.NoError(t, err)

			buildpackTOML, err := ioutil.ReadFile(filepath.Join("testdata", "original-buildpack.toml"))
			require.NoError(t, err)

			taskCmd = exec.Command(
				"go", "run", "-mod=vendor", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-stacks",
				"--dependency-builds-config", string(dependencyBuildsConfig),
				"--buildpack-toml", string(buildpackTOML),
				"--output-dir", outputDir,
				"--buildpack-toml-output-path", "buildpack.toml",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			expectedBuildpackTOML, err := ioutil.ReadFile(filepath.Join("testdata", "expected-buildpack.toml"))
			require.NoError(t, err)

			actualBuildpackTOML, err := ioutil.ReadFile(filepath.Join(outputDir, "buildpack.toml"))
			require.NoError(t, err)

			assert.Equal(t, string(expectedBuildpackTOML), string(actualBuildpackTOML))

			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Update stacks and mixins")
		})
	})

	when("there are no changes in buildpack.toml", func() {
		it.Before(func() {
			expectedBuildpackTOML, err := ioutil.ReadFile(filepath.Join("testdata", "expected-buildpack.toml"))
			require.NoError(t, err)

			err = ioutil.WriteFile(filepath.Join(outputDir, "buildpack.toml"), expectedBuildpackTOML, 0644)
			require.NoError(t, err)

			require.NoError(t, exec.Command("git", "-C", outputDir, "add", "buildpack.toml").Run())
			require.NoError(t, exec.Command("git", "-C", outputDir, "commit", "-m", "initial commit").Run())
		})

		it("does not make a commit", func() {
			dependencyBuildsConfig, err := ioutil.ReadFile(filepath.Join("testdata", "dependency-builds-config.yml"))
			require.NoError(t, err)

			sourceBuildpackTOML, err := ioutil.ReadFile(filepath.Join("testdata", "original-buildpack.toml"))
			require.NoError(t, err)

			taskCmd = exec.Command(
				"go", "run", "-mod=vendor", "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-stacks",
				"--dependency-builds-config", string(dependencyBuildsConfig),
				"--buildpack-toml", string(sourceBuildpackTOML),
				"--output-dir", outputDir,
				"--buildpack-toml-output-path", "buildpack.toml",
			)
			taskCmd.Env = append(taskCmd.Env, envVars...)

			taskOutput, err := taskCmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			cmd := exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "initial commit")
		})
	})
}
