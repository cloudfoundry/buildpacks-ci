package main_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/BurntSushi/toml"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpdateCNBDependencyTask(t *testing.T) {
	spec.Run(t, "update-cnb-dependency task", testUpdateCNBDependencyTask, spec.Report(report.Terminal{}))
}

func testUpdateCNBDependencyTask(t *testing.T, when spec.G, it spec.S) {
	when("updating a child CNB", func() {
		var (
			outputDir = "testdata/updating-child-cnb/artifacts"
			envVars   = []string{
				"VERSION_LINE=2.X.X",
				"VERSIONS_TO_KEEP=2",
				"DEPRECATION_DATE=2040-01-01",
				"DEPRECATION_LINK=some-updated-deprecation-link",
				"HOME=" + os.Getenv("HOME"),
				"PATH=" + os.Getenv("PATH"),
			}
		)

		it.Before(func() {
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())
		})

		it.After(func() {
			require.NoError(t, os.RemoveAll(outputDir))
		})

		it("updates the dep in the buildpack.toml deps", func() {
			cmd := exec.Command("go", "run", "../../")
			cmd.Dir = "./testdata/updating-child-cnb"
			cmd.Env = append(cmd.Env, envVars...)
			taskOutput, err := cmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			var buildpackDescriptor BuildpackToml
			_, err = toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackDescriptor)
			require.NoError(t, err)

			assert.Equal(t, []Dependency{
				{
					ID:      "some-dep",
					Name:    "Some Dep",
					Sha256:  "sha256-for-bionic-binary-1.0.0",
					Stacks:  []string{"io.buildpacks.stacks.bionic"},
					URI:     "https://example.org/some-dep-1.0.0.tgz",
					Version: "1.0.0",
				},
				{
					ID:           "some-dep",
					Name:         "Some Dep",
					Sha256:       "sha256-for-cflinuxfs3-binary-1.0.0",
					Source:       "https://example.org/some-dep-1.0.0-source.tgz",
					SourceSha256: "sha256-for-source-1.0.0",
					Stacks:       []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-1.0.0.linux-amd64-cflinuxfs3-aaaaaaaa.tar.gz",
					Version:      "1.0.0",
				},
				{
					ID:      "some-dep",
					Name:    "Some Dep",
					Sha256:  "sha256-for-bionic-binary-1.0.1",
					Stacks:  []string{"io.buildpacks.stacks.bionic"},
					URI:     "https://example.org/some-dep-1.0.1.tgz",
					Version: "1.0.1",
				},
				{
					ID:           "some-dep",
					Name:         "Some Dep",
					Sha256:       "sha256-for-cflinuxfs3-binary-1.0.1",
					Source:       "https://example.org/some-dep-1.0.1-source.tgz",
					SourceSha256: "sha256-for-source-1.0.1",
					Stacks:       []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-1.0.1.linux-amd64-cflinuxfs3-bbbbbbbb.tar.gz",
					Version:      "1.0.1",
				},
				{
					ID:      "some-dep",
					Name:    "Some Dep",
					Sha256:  "sha256-for-bionic-binary-2.0.1",
					Stacks:  []string{"io.buildpacks.stacks.bionic"},
					URI:     "https://example.org/some-dep-2.0.1.tgz",
					Version: "2.0.1",
				},
				{
					ID:           "some-dep",
					Name:         "Some Dep",
					Sha256:       "sha256-for-cflinuxfs3-binary-2.0.1",
					Source:       "https://example.org/some-dep-2.0.1-source.tgz",
					SourceSha256: "sha256-for-source-2.0.1",
					Stacks:       []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-2.0.1.linux-amd64-cflinuxfs3-dddddddd.tar.gz",
					Version:      "2.0.1",
				},
				{
					ID:      "some-dep",
					Name:    "Some Dep",
					Sha256:  "sha256-for-bionic-binary-2.1.0",
					Stacks:  []string{"io.buildpacks.stacks.bionic"},
					URI:     "https://example.org/some-dep-2.1.0.tgz",
					Version: "2.1.0",
				},
				{
					ID:           "some-dep",
					Name:         "Some Dep",
					Sha256:       "sha256-for-cflinuxfs3-binary-2.1.0",
					Source:       "https://example.org/some-dep-2.1.0-source.tgz",
					SourceSha256: "sha256-for-source-2.1.0",
					Stacks:       []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/some-dep/some-dep-2.1.0.linux-amd64-cflinuxfs3-eeeeeeee.tar.gz",
					Version:      "2.1.0",
				},
			}, buildpackDescriptor.Metadata.Dependencies)
		})

		it("updates deprecation dates", func() {
			cmd := exec.Command("go", "run", "../../")
			cmd.Dir = "./testdata/updating-child-cnb"
			cmd.Env = append(cmd.Env, envVars...)
			taskOutput, err := cmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			var buildpackDescriptor BuildpackToml
			_, err = toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackDescriptor)
			require.NoError(t, err)

			assert.Equal(t, []DependencyDeprecationDate{
				{
					Name:        "some-dep",
					VersionLine: "1.x.x",
					Link:        "some-deprecation-link",
					Date:        time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC),
				},
				{
					Name:        "some-dep",
					VersionLine: "2.x.x",
					Link:        "some-updated-deprecation-link",
					Date:        time.Date(2040, 1, 1, 0, 0, 0, 0, time.UTC),
				},
			}, buildpackDescriptor.Metadata.DependencyDeprecationDates)
		})

		it("shows the added and removed dep versions in the commit message", func() {
			cmd := exec.Command("go", "run", "../../")
			cmd.Dir = "./testdata/updating-child-cnb"
			cmd.Env = append(cmd.Env, envVars...)
			taskOutput, err := cmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			cmd = exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Add some-dep 2.1.0, remove some-dep 2.0.0")
			assert.Contains(t, string(latestCommitMessage), "for stack(s) io.buildpacks.stacks.bionic, org.cloudfoundry.stacks.cflinuxfs3 [#111111111]")
		})
	})

	when("updating a parent CNB", func() {
		var (
			outputDir = "testdata/updating-parent-cnb/artifacts"
			envVars   = []string{
				"VERSION_LINE=latest",
				"VERSIONS_TO_KEEP=1",
				"HOME=" + os.Getenv("HOME"),
				"PATH=" + os.Getenv("PATH"),
			}
		)

		it.Before(func() {
			require.NoError(t, os.RemoveAll(outputDir))
			require.NoError(t, os.Mkdir(outputDir, 0755))
			require.NoError(t, exec.Command("git", "-C", outputDir, "init").Run())
		})

		it.After(func() {
			require.NoError(t, os.RemoveAll(outputDir))
		})

		it("updates the child CNB in the buildpack.toml deps", func() {
			cmd := exec.Command("go", "run", "../../")
			cmd.Dir = "./testdata/updating-parent-cnb"
			cmd.Env = append(cmd.Env, envVars...)
			taskOutput, err := cmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			var buildpackDescriptor BuildpackToml
			_, err = toml.DecodeFile(filepath.Join(outputDir, "buildpack.toml"), &buildpackDescriptor)
			require.NoError(t, err)

			assert.Equal(t, []Dependency{
				{
					ID:           "org.cloudfoundry.some-child",
					Sha256:       "sha256-for-binary-1.0.1",
					Source:       "https://github.com/cloudfoundry/some-child-cnb/archive/v1.0.1.tar.gz",
					SourceSha256: "sha256-for-source-1.0.1",
					Stacks:       []string{"io.buildpacks.stacks.bionic"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/org.cloudfoundry.some-child/org.cloudfoundry.some-child-1.0.1-any-stack-bbbbbbbb.tgz",
					Version:      "1.0.1",
				},
				{
					ID:           "org.cloudfoundry.some-child",
					Sha256:       "sha256-for-binary-1.0.1",
					Source:       "https://github.com/cloudfoundry/some-child-cnb/archive/v1.0.1.tar.gz",
					SourceSha256: "sha256-for-source-1.0.1",
					Stacks:       []string{"org.cloudfoundry.stacks.cflinuxfs3"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/org.cloudfoundry.some-child/org.cloudfoundry.some-child-1.0.1-any-stack-bbbbbbbb.tgz",
					Version:      "1.0.1",
				},
				{
					ID:           "org.cloudfoundry.some-child",
					Sha256:       "sha256-for-binary-1.0.1",
					Source:       "https://github.com/cloudfoundry/some-child-cnb/archive/v1.0.1.tar.gz",
					SourceSha256: "sha256-for-source-1.0.1",
					Stacks:       []string{"org.cloudfoundry.stacks.tiny"},
					URI:          "https://buildpacks.cloudfoundry.org/dependencies/org.cloudfoundry.some-child/org.cloudfoundry.some-child-1.0.1-any-stack-bbbbbbbb.tgz",
					Version:      "1.0.1",
				},
			}, buildpackDescriptor.Metadata.Dependencies)
		})

		it("shows the added and removed child CNB versions in the commit message", func() {
			cmd := exec.Command("go", "run", "../../")
			cmd.Dir = "./testdata/updating-parent-cnb"
			cmd.Env = append(cmd.Env, envVars...)
			taskOutput, err := cmd.CombinedOutput()
			require.NoError(t, err, string(taskOutput))

			cmd = exec.Command("git", "-C", outputDir, "log", "-1", "--format=%B")
			latestCommitMessage, err := cmd.CombinedOutput()
			require.NoError(t, err, string(latestCommitMessage))
			assert.Contains(t, string(latestCommitMessage), "Add org.cloudfoundry.some-child 1.0.1, remove org.cloudfoundry.some-child 1.0.0")
			assert.Contains(t, string(latestCommitMessage), "for stack(s) io.buildpacks.stacks.bionic, org.cloudfoundry.stacks.cflinuxfs3, org.cloudfoundry.stacks.tiny [#111111111]")
		})
	})
}
