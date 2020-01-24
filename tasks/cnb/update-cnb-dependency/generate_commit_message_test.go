package main_test

import (
	"testing"

	"github.com/cloudfoundry/buildpacks-ci/tasks/cnb/helpers"
	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
)

func TestGenerateCommitMessage(t *testing.T) {
	spec.Run(t, "GenerateCommitMessage", testGenerateCommitMessage, spec.Report(report.Terminal{}))
}

func testGenerateCommitMessage(t *testing.T, when spec.G, it spec.S) {
	var depAdded helpers.Dependency
	it.Before(func() {
		depAdded = helpers.Dependency{
			ID:      "some-id",
			Version: "3.0.0",
		}
	})

	when("a version is added", func() {
		it("shows the version and stacks of the new dep", func() {
			oldDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1", "some-stack-2"}, Version: "2.0.0"},
			}
			newDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2", "some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0"},
			}
			depAdded := helpers.Dependency{
				ID:      "some-id",
				Version: "3.0.0",
			}

			commitMessage := GenerateCommitMessage(oldDeps, newDeps, depAdded, 123456789)
			assert.Equal(t, `Add some-id 3.0.0

for stack(s) some-stack-1, some-stack-2 [#123456789]`, commitMessage)
		})
	})

	when("a version is added and removed", func() {
		it("shows the version and stacks of the new and old dependencies", func() {
			oldDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1", "some-stack-2"}, Version: "2.0.0"},
			}
			newDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-2", "some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
			}

			commitMessage := GenerateCommitMessage(oldDeps, newDeps, depAdded, 123456789)
			assert.Equal(t, `Add some-id 3.0.0, remove some-id 1.0.0

for stack(s) some-stack-1, some-stack-2 [#123456789]`, commitMessage)
		})
	})

	when("a version is rebuilt", func() {
		it("shows the version and stacks of the rebuilt dep", func() {
			oldDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
			}
			newDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0", SHA256: "some-new-sha"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0", SHA256: "some-new-sha"},
			}

			commitMessage := GenerateCommitMessage(oldDeps, newDeps, depAdded, 123456789)
			assert.Equal(t, `Rebuild some-id 3.0.0

for stack(s) some-stack-1, some-stack-2 [#123456789]`, commitMessage)
		})
	})

	when("a version is rebuilt and removed", func() {
		it("shows the version and stacks of the rebuilt and old dependencies", func() {
			oldDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
			}
			newDeps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0", SHA256: "some-new-sha"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0", SHA256: "some-new-sha"},
			}

			commitMessage := GenerateCommitMessage(oldDeps, newDeps, depAdded, 123456789)
			assert.Equal(t, `Rebuild some-id 3.0.0, remove some-id 1.0.0

for stack(s) some-stack-1, some-stack-2 [#123456789]`, commitMessage)
		})
	})

	when("dependencies have not changed", func() {
		it("is empty", func() {
			deps := []helpers.Dependency{
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-1"}, Version: "3.0.0"},
				{ID: "some-id", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
			}
			commitMessage := GenerateCommitMessage(deps, deps, depAdded, 123456789)
			assert.Empty(t, commitMessage)
		})
	})
}
