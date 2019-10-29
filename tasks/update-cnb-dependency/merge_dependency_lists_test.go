package main_test

import (
	"testing"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMergeDependencyLists(t *testing.T) {
	spec.Run(t, "MergeDependencyLists", testMergeDependencyLists, spec.Report(report.Terminal{}))
}

func testMergeDependencyLists(t *testing.T, when spec.G, it spec.S) {
	when("the new deps IDs are different", func() {
		it("adds the deps", func() {
			existingDeps := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
			}
			depsToAdd := []Dependency{
				{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
			}

			newDeps, err := MergeDependencyLists(existingDeps, depsToAdd)
			require.NoError(t, err)
			assert.Equal(t, []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
			}, newDeps)
		})
	})

	when("the new deps stacks are different", func() {
		it("adds the deps", func() {
			existingDeps := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
			}
			depsToAdd := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
			}

			newDeps, err := MergeDependencyLists(existingDeps, depsToAdd)
			require.NoError(t, err)
			assert.Equal(t, []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
			}, newDeps)
		})
	})

	when("the new deps versions are different", func() {
		it("adds the deps", func() {
			existingDeps := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
			}
			depsToAdd := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
			}

			newDeps, err := MergeDependencyLists(existingDeps, depsToAdd)
			require.NoError(t, err)
			assert.Equal(t, []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
			}, newDeps)
		})
	})

	when("the new deps are the same", func() {
		it("overwrites the existing deps", func() {
			existingDeps := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
			}
			depsToAdd := []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0", Sha256: "some-new-sha"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0", Sha256: "some-new-sha"},
			}

			newDeps, err := MergeDependencyLists(existingDeps, depsToAdd)
			require.NoError(t, err)
			assert.Equal(t, []Dependency{
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0", Sha256: "some-new-sha"},
				{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0", Sha256: "some-new-sha"},
			}, newDeps)
		})
	})
}
