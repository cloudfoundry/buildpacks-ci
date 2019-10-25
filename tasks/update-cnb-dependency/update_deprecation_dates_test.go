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
	name1 := "some-name-1"
	name2 := "some-name-2"
	versionLine1 := "1.x.x"
	versionLine2 := "2.x.x"
	deprecationDateString := "2019-01-01"
	deprecationDate := time.Date(2019, 1, 1, 0, 0, 0, 0, time.UTC)
	deprecationLink := "some-link"
	deprecationMatch := "some-match"

	when("the dep name and version line are not in existing deprecation dates", func() {
		when("the dep name is different", func() {
			it("adds a new deprecation date sorting by name and version", func() {
				existingDeprecationDates := []DependencyDeprecationDate{
					{Name: name2, VersionLine: versionLine1},
					{Name: name2, VersionLine: versionLine2},
				}

				updatedDeprecationDates, err := UpdateDeprecationDates(
					existingDeprecationDates,
					name1,
					versionLine1,
					deprecationDateString,
					deprecationLink,
					deprecationMatch,
				)
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

				updatedDeprecationDates, err := UpdateDeprecationDates(
					existingDeprecationDates,
					name1,
					versionLine2,
					deprecationDateString,
					deprecationLink,
					deprecationMatch,
				)
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

			updatedDeprecationDates, err := UpdateDeprecationDates(
				existingDeprecationDates,
				name1,
				versionLine1,
				"2020-01-01",
				"some-new-link",
				"some-new-match",
			)
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
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				"null",
				deprecationLink,
				deprecationMatch,
			)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)
		})
	})

	when("deprecation link is null", func() {
		it("does not add the deprecation date", func() {
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				deprecationDateString,
				"null",
				deprecationMatch,
			)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)

		})
	})

	when("deprecation date is empty", func() {
		it("does not add the deprecation date", func() {
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				"",
				deprecationLink,
				deprecationMatch,
			)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)
		})
	})

	when("deprecation link is empty", func() {
		it("does not add the deprecation date", func() {
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				deprecationDateString,
				"",
				deprecationMatch,
			)
			require.NoError(t, err)
			assert.Len(t, updatedDeprecationDates, 0)

		})
	})

	when("match is 'null'", func() {
		it("does not set match", func() {
			updatedDeprecationDates, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				deprecationDateString,
				deprecationLink,
				"null",
			)
			require.NoError(t, err)
			assert.Equal(t, []DependencyDeprecationDate{
				{Name: name1, VersionLine: versionLine1, Date: deprecationDate, Link: deprecationLink, Match: ""},
			}, updatedDeprecationDates)
		})
	})

	when("deprecation date is not in the correct format", func() {
		it("returns an error", func() {
			_, err := UpdateDeprecationDates(
				nil,
				name1,
				versionLine1,
				"invalid-date",
				deprecationLink,
				"null",
			)
			assert.EqualError(t, err, `could not parse date 'invalid-date', must be in format YYYY-MM-DD`)
		})
	})
}
