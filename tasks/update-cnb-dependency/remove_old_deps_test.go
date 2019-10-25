package main_test

import (
	"testing"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRemoveOldDeps(t *testing.T) {
	spec.Run(t, " RemoveOldDeps", testRemoveOldDeps, spec.Report(report.Terminal{}))
}

func testRemoveOldDeps(t *testing.T, when spec.G, it spec.S) {
	var id = "some-id"
	var otherID = "some-other-id"
	var stack1 = "some-stack-1"
	var stack2 = "some-stack-2"

	when("version_line is `latest`", func() {
		deps := []Dependency{
			{ID: id, Stacks: []string{stack1}, Version: "2.0.0"},
			{ID: id, Stacks: []string{stack2}, Version: "2.0.0"},
			{ID: id, Stacks: []string{stack1}, Version: "3.0.0"},
			{ID: id, Stacks: []string{stack2}, Version: "3.0.0"},
			{ID: id, Stacks: []string{stack1}, Version: "4.0.0"},
			{ID: id, Stacks: []string{stack2}, Version: "4.0.0"},
			{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
		}

		it("keeps n versions", func() {
			updatedDeps, err := RemoveOldDeps(deps, id, "latest", 2)
			require.NoError(t, err)
			assert.Equal(t, updatedDeps, []Dependency{
				{ID: id, Stacks: []string{stack1}, Version: "3.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "3.0.0"},
				{ID: id, Stacks: []string{stack1}, Version: "4.0.0"},
				{ID: id, Stacks: []string{stack2}, Version: "4.0.0"},
				{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
			})
		})
	})

	when("version_line is specified as a version designator eg `4.x`", func() {
		deps := []Dependency{
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
			updatedDeps, err := RemoveOldDeps(deps, id, "4.x", 1)
			require.NoError(t, err)
			assert.Equal(t, updatedDeps, []Dependency{
				{ID: id, Stacks: []string{stack1}, Version: "3.0.1"},
				{ID: id, Stacks: []string{stack2}, Version: "3.0.1"},
				{ID: id, Stacks: []string{stack1}, Version: "4.1.0"},
				{ID: id, Stacks: []string{stack2}, Version: "4.1.0"},
				{ID: otherID, Stacks: []string{stack1}, Version: "1.0.0"},
			})
		})

		it("keeps n versions in specified minor line", func() {
			updatedDeps, err := RemoveOldDeps(deps, id, "4.0.x", 1)
			require.NoError(t, err)
			assert.Equal(t, updatedDeps, []Dependency{
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
		deps := []Dependency{
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
			updatedDeps, err := RemoveOldDeps(deps, id, "1.0.1x", 1)
			require.NoError(t, err)
			assert.Equal(t, updatedDeps, []Dependency{
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
		_, err := RemoveOldDeps(nil, id, "", 0)
		assert.EqualError(t, err, `please specify a valid number of versions (>0) to retain`)
	})
}
