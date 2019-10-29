package main_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
)

func TestUpdateDeprecationDates(t *testing.T) {
	spec.Run(t, "UpdateDeprecationDates", testUpdateDeprecationDates, spec.Report(report.Terminal{}))
}

func testUpdateDeprecationDates(t *testing.T, when spec.G, it spec.S) {
	var envs EnvVars
	name1 := "some-name-1"
	name2 := "some-name-2"
	versionLine1 := "1.x.x"
	versionLine2 := "2.x.x"
	deprecationDateString := "2019-01-01"
	deprecationDate := time.Date(2019, 1, 1, 0, 0, 0, 0, time.UTC)
	deprecationLink := "some-link"
	deprecationMatch := "some-match"

	it.Before(func() {
		envs = EnvVars{
			DeprecationDate:  deprecationDateString,
			DeprecationLink:  deprecationLink,
			DeprecationMatch: deprecationMatch,
			VersionLine:      versionLine1,
			VersionsToKeep:   0,
		}
	})

	when("the dep name and version line are not in existing deprecation dates", func() {
		when("the dep name is different", func() {
			it("adds a new deprecation date sorting by name and version", func() {
				existingDeprecationDates := []DependencyDeprecationDate{
					{Name: name2, VersionLine: versionLine1},
					{Name: name2, VersionLine: versionLine2},
				}

				updatedDeprecationDates, err := UpdateDeprecationDates(
					existingDeprecationDates, name1, envs)
				require.NoError(t, err)
				assert.Equal(t, []DependencyDeprecationDate{
					{Name: name1, VersionLine: versionLine1, Date: deprecationDate, Link: deprecationLink, Match: deprecationMatch},
					{Name: name2, VersionLine: versionLine1},
					{Name: name2, VersionLine: versionLine2},
				}, updatedDeprecationDates)
			})
		})

		when("the version line is different", func() {
			it("adds a new deprecation date sorting by name and version", func() {
				existingDeprecationDates := []DependencyDeprecationDate{
					{Name: name1, VersionLine: versionLine1},
					{Name: name2, VersionLine: versionLine2},
				}

				envs.VersionLine = versionLine2
				updatedDeprecationDates, err := UpdateDeprecationDates(
					existingDeprecationDates, name1, envs)
				require.NoError(t, err)
				assert.Equal(t, []DependencyDeprecationDate{
					{Name: name1, VersionLine: versionLine1},
					{Name: name1, VersionLine: versionLine2, Date: deprecationDate, Link: deprecationLink, Match: deprecationMatch},
					{Name: name2, VersionLine: versionLine2},
				}, updatedDeprecationDates)
			})
		})
	})

	when("the dep name and version line are in existing deprecation dates", func() {
		it("updates the deprecation date", func() {
			existingDeprecationDates := []DependencyDeprecationDate{
				{Name: name1, VersionLine: versionLine1, Date: deprecationDate, Link: deprecationLink, Match: deprecationMatch},
				{Name: name2, VersionLine: versionLine2},
			}

			envs.DeprecationLink = "some-new-link"
			envs.DeprecationMatch = "some-new-match"
			envs.DeprecationDate = "2020-01-01"
			updatedDeprecationDates, err := UpdateDeprecationDates(
				existingDeprecationDates, name1, envs)
			require.NoError(t, err)
			newDate := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
			assert.Equal(t, []DependencyDeprecationDate{
				{Name: name1, VersionLine: versionLine1, Date: newDate, Link: "some-new-link", Match: "some-new-match"},
				{Name: name2, VersionLine: versionLine2},
			}, updatedDeprecationDates)
		})
	})

	when("deprecation date is null", func() {
		it("does not add the deprecation date", func() {
			envs.DeprecationDate = "null"
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil, name1, envs)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)
		})
	})

	when("deprecation link is null", func() {
		it("does not add the deprecation date", func() {
			envs.DeprecationLink = "null"
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil, name1, envs)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)

		})
	})

	when("deprecation date is empty", func() {
		it("does not add the deprecation date", func() {
			envs.DeprecationDate = ""
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil, name1, envs)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)
		})
	})

	when("deprecation link is empty", func() {
		it("does not add the deprecation date", func() {
			envs.DeprecationLink = ""
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil, name1, envs)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)

		})
	})

	when("match is 'null'", func() {
		it("does not set match", func() {
			envs.DeprecationMatch = "null"
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil, name1, envs)
			require.NoError(t, err)
			assert.Equal(t, []DependencyDeprecationDate{
				{Name: name1, VersionLine: versionLine1, Date: deprecationDate, Link: deprecationLink, Match: ""},
			}, updatedDeprecationDates)
		})
	})

	when("deprecation date is not in the correct format", func() {
		it("returns an error", func() {
			envs.DeprecationDate = "invalid-date"
			envs.DeprecationMatch = "null"
			_, err := UpdateDeprecationDates(
				nil, name1, envs)
			assert.EqualError(t, err, `could not parse date 'invalid-date', must be in format YYYY-MM-DD`)
		})
	})
}
