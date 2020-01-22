package main_test

import (
	"sort"
	"testing"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDependencies(t *testing.T) {
	spec.Run(t, "Dependencies", testDependencies, spec.Report(report.Terminal{}))
}

func testDependencies(t *testing.T, when spec.G, it spec.S) {
	when("MergeDependencies", func() {
		when("the new deps IDs are different", func() {
			it("adds the deps", func() {
				existingDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				}
				depsToAdd := Dependencies{
					{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				}

				newDeps := existingDeps.MergeWith(depsToAdd)
				assert.Equal(t, Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				}, newDeps)
			})
		})

		when("the new deps stacks are different", func() {
			it("adds the deps", func() {
				existingDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				}
				depsToAdd := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
				}

				newDeps := existingDeps.MergeWith(depsToAdd)
				assert.Equal(t, Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
				}, newDeps)
			})
		})

		when("the new deps versions are different", func() {
			it("adds the deps", func() {
				existingDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
				}
				depsToAdd := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
				}

				newDeps := existingDeps.MergeWith(depsToAdd)
				assert.Equal(t, Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
				}, newDeps)
			})
		})

		when("the new deps are the same", func() {
			it("overwrites the existing deps", func() {
				existingDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
				}
				depsToAdd := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0", SHA256: "some-new-sha"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0", SHA256: "some-new-sha"},
				}

				newDeps := existingDeps.MergeWith(depsToAdd)
				assert.Equal(t, Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0", SHA256: "some-new-sha"},
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "2.0.0", SHA256: "some-new-sha"},
				}, newDeps)
			})
		})
	})

	when("RemoveOldDeps", func() {
		var id = "some-id"
		var otherID = "some-other-id"
		var stack1 = "some-stack-1"
		var stack2 = "some-stack-2"

		when("version_line is `latest`", func() {
			deps := Dependencies{
				{ID: id, Stacks: []string{stack1}, Version: "2.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "2.0.0"},
				{ID: id, Stacks: []string{stack1}, Version: "3.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "3.0.0"},
				{ID: id, Stacks: []string{stack1}, Version: "4.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "4.0.0"},
				{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
			}

			it("keeps n versions", func() {
				updatedDeps, err := deps.RemoveOldDeps(id, "latest", 2)
				require.NoError(t, err)
				assert.Equal(t, updatedDeps, Dependencies{
					{ID: id, Stacks: []string{stack1}, Version: "3.0.0"},
					{ID: id, Stacks: []string{stack2}, Version: "3.0.0"},
					{ID: id, Stacks: []string{stack1}, Version: "4.0.0"},
					{ID: id, Stacks: []string{stack2}, Version: "4.0.0"},
					{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
				})
			})
		})

		when("version_line is specified as a version designator eg `4.x`", func() {
			deps := Dependencies{
				{ID: id, Stacks: []string{stack1}, Version: "3.0.1"},
				{ID: id, Stacks: []string{stack2}, Version: "3.0.1"},
				{ID: id, Stacks: []string{stack1}, Version: "4.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "4.0.0"},
				{ID: id, Stacks: []string{stack1}, Version: "4.0.1"},
				{ID: id, Stacks: []string{stack2}, Version: "4.0.1"},
				{ID: id, Stacks: []string{stack1}, Version: "4.1.0"},
				{ID: id, Stacks: []string{stack2}, Version: "4.1.0"},
				{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
			}

			it("keeps n versions with the specified major line", func() {
				updatedDeps, err := deps.RemoveOldDeps(id, "4.x", 1)
				require.NoError(t, err)
				assert.Equal(t, updatedDeps, Dependencies{
					{ID: id, Stacks: []string{stack1}, Version: "3.0.1"},
					{ID: id, Stacks: []string{stack2}, Version: "3.0.1"},
					{ID: id, Stacks: []string{stack1}, Version: "4.1.0"},
					{ID: id, Stacks: []string{stack2}, Version: "4.1.0"},
					{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
				})
			})

			it("keeps n versions in specified minor line", func() {
				updatedDeps, err := deps.RemoveOldDeps(id, "4.0.x", 1)
				require.NoError(t, err)
				assert.Equal(t, updatedDeps, Dependencies{
					{ID: id, Stacks: []string{stack1}, Version: "3.0.1"},
					{ID: id, Stacks: []string{stack2}, Version: "3.0.1"},
					{ID: id, Stacks: []string{stack1}, Version: "4.0.1"},
					{ID: id, Stacks: []string{stack2}, Version: "4.0.1"},
					{ID: id, Stacks: []string{stack1}, Version: "4.1.0"},
					{ID: id, Stacks: []string{stack2}, Version: "4.1.0"},
					{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
				})
			})
		})

		when("version_line is specified as a Microsoft version designator eg `1.0.1x`", func() {
			deps := Dependencies{
				{ID: id, Stacks: []string{stack1}, Version: "1.0.100"},
				{ID: id, Stacks: []string{stack2}, Version: "1.0.100"},
				{ID: id, Stacks: []string{stack1}, Version: "1.0.101"},
				{ID: id, Stacks: []string{stack2}, Version: "1.0.101"},
				{ID: id, Stacks: []string{stack1}, Version: "2.0.100"},
				{ID: id, Stacks: []string{stack2}, Version: "2.0.100"},
				{ID: id, Stacks: []string{stack1}, Version: "2.0.101"},
				{ID: id, Stacks: []string{stack2}, Version: "2.0.101"},
				{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
			}

			it("keeps n versions with the specified line", func() {
				updatedDeps, err := deps.RemoveOldDeps(id, "1.0.1x", 1)
				require.NoError(t, err)
				assert.Equal(t, updatedDeps, Dependencies{
					{ID: id, Stacks: []string{stack1}, Version: "1.0.101"},
					{ID: id, Stacks: []string{stack2}, Version: "1.0.101"},
					{ID: id, Stacks: []string{stack1}, Version: "2.0.100"},
					{ID: id, Stacks: []string{stack2}, Version: "2.0.100"},
					{ID: id, Stacks: []string{stack1}, Version: "2.0.101"},
					{ID: id, Stacks: []string{stack2}, Version: "2.0.101"},
					{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
				})
			})
		})

		it("errors on invalid number to keep", func() {
			deps := Dependencies{}
			_, err := deps.RemoveOldDeps(id, "", 0)
			assert.EqualError(t, err, `please specify a valid number of versions (>0) to retain`)
		})
	})

	when("CollapseEqualDependencies", func() {
		when("there are equal dependencies to be collapsed", func() {
			it("combines equal dependencies, and leaves dependencies which aren't equal", func() {
				originalDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-1", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-3"}, Version: "2.0.0"},
					{ID: "some-id-3", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
				}

				collapsedDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1", "some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-1", "some-stack-2", "some-stack-3"}, Version: "2.0.0"},
					{ID: "some-id-3", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
				}

				newDeps := originalDeps.CollapseByStack()
				assert.Equal(t, collapsedDeps, newDeps)
			})
		})

		when("there are no equal dependencies to be collapsed", func() {
			it("leaves the dependencies the same", func() {
				originalDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-3", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-4", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
					{ID: "some-id-5", Stacks: []string{"some-stack-3"}, Version: "2.0.0"},
					{ID: "some-id-6", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
				}

				collapsedDeps := Dependencies{
					{ID: "some-id-1", Stacks: []string{"some-stack-1"}, Version: "1.0.0"},
					{ID: "some-id-2", Stacks: []string{"some-stack-2"}, Version: "1.0.0"},
					{ID: "some-id-3", Stacks: []string{"some-stack-1"}, Version: "2.0.0"},
					{ID: "some-id-4", Stacks: []string{"some-stack-2"}, Version: "2.0.0"},
					{ID: "some-id-5", Stacks: []string{"some-stack-3"}, Version: "2.0.0"},
					{ID: "some-id-6", Stacks: []string{"some-stack-2"}, Version: "3.0.0"},
				}

				newDeps := originalDeps.CollapseByStack()
				assert.Equal(t, collapsedDeps, newDeps)
			})
		})
	})

	when.Focus("SortDependencies", func() {
		it("sorts by name, then version, then stacks", func() {
			deps := Dependencies{
				{ID: "some-id-2", Version: "2.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-1", Version: "2.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-2", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-2", Version: "2.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-1", Version: "2.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-2", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
			}
			sortedDeps := Dependencies{
				{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-1", Version: "2.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-1", Version: "2.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-2", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-2", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
				{ID: "some-id-2", Version: "2.0.0", Stacks: []string{"some-stack-1"}},
				{ID: "some-id-2", Version: "2.0.0", Stacks: []string{"some-stack-2"}},
			}

			sort.Slice(deps, deps.SortDependencies())

			assert.Equal(t, sortedDeps, deps)
		})

		when("dependencies have multiple stacks", func() {
			it("sorts stacks alphabetically, with fewer stacks being sorted first", func() {
				deps := Dependencies{
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-3"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-2", "some-stack-3"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-2"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-3"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
				}
				sortedDeps := Dependencies{
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-2"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-2", "some-stack-3"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-1", "some-stack-3"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-2"}},
					{ID: "some-id-1", Version: "1.0.0", Stacks: []string{"some-stack-3"}},
				}

				sort.Slice(deps, deps.SortDependencies())

				assert.Equal(t, sortedDeps, deps)
			})
		})
	})
}
