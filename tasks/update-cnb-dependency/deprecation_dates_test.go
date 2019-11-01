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
	spec.Run(t, "DeprecationDates", testDeprecationDates, spec.Report(report.Terminal{}))
}

func testDeprecationDates(t *testing.T, when spec.G, it spec.S) {
	when("Update", func() {

		var newDepDeprecationDate DependencyDeprecationDate
		name1 := "some-name-1"
		name2 := "some-name-2"
		versionLine1 := "1.x.x"
		versionLine2 := "2.x.x"
		deprecationDate1 := time.Date(2019, 1, 1, 0, 0, 0, 0, time.UTC)
		deprecationDate2 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
		deprecationLink := "some-link"
		deprecationMatch := "some-match"

		it.Before(func() {
			newDepDeprecationDate = DependencyDeprecationDate{
				Date:        deprecationDate1,
				Link:        deprecationLink,
				Name:        name1,
				VersionLine: versionLine1,
				Match:       deprecationMatch,
			}
		})

		when("the dep name and version line are not in existing deprecation dates", func() {
			when("the dep name is different", func() {
				it("adds a new deprecation date sorting by name and version", func() {
					existingDeprecationDates := DeprecationDates{
						{Name: name2, VersionLine: versionLine1},
						{Name: name2, VersionLine: versionLine2},
					}

					updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
					require.NoError(t, err)
					assert.Equal(t, DeprecationDates{
						{Name: name1, VersionLine: versionLine1, Date: deprecationDate1, Link: deprecationLink, Match: deprecationMatch},
						{Name: name2, VersionLine: versionLine1},
						{Name: name2, VersionLine: versionLine2},
					}, updatedDeprecationDates)
				})
			})

			when("the version line is different", func() {
				it("adds a new deprecation date sorting by name and version", func() {
					existingDeprecationDates := DeprecationDates{
						{Name: name1, VersionLine: versionLine1},
						{Name: name2, VersionLine: versionLine2},
					}

					newDepDeprecationDate.VersionLine = versionLine2
					updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
					require.NoError(t, err)
					assert.Equal(t, DeprecationDates{
						{Name: name1, VersionLine: versionLine1},
						{Name: name1, VersionLine: versionLine2, Date: deprecationDate1, Link: deprecationLink, Match: deprecationMatch},
						{Name: name2, VersionLine: versionLine2},
					}, updatedDeprecationDates)
				})
			})
		})

		when("the dep name and version line are in existing deprecation dates", func() {
			it("updates the deprecation date", func() {
				existingDeprecationDates := DeprecationDates{
					{Name: name1, VersionLine: versionLine1, Date: deprecationDate1, Link: deprecationLink, Match: deprecationMatch},
					{Name: name2, VersionLine: versionLine2},
				}

				newDepDeprecationDate.Link = "some-new-link"
				newDepDeprecationDate.Match = "some-new-match"
				newDepDeprecationDate.Date = deprecationDate2
				updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
				require.NoError(t, err)
				assert.Equal(t, DeprecationDates{
					{Name: name1, VersionLine: versionLine1, Date: deprecationDate2, Link: "some-new-link", Match: "some-new-match"},
					{Name: name2, VersionLine: versionLine2},
				}, updatedDeprecationDates)
			})
		})

		when("deprecation date is null", func() {
			it("does not add the deprecation date", func() {
				newDepDeprecationDate.Date = time.Time{}
				existingDeprecationDates := DeprecationDates{}
				updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
				require.NoError(t, err)
				assert.Len(t, updatedDeprecationDates, 0)
			})
		})

		when("deprecation link is empty", func() {
			it("does not add the deprecation date", func() {
				existingDeprecationDates := DeprecationDates{}
				newDepDeprecationDate.Link = ""
				updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
				require.NoError(t, err)
				assert.Len(t, updatedDeprecationDates, 0)

			})
		})

		when("match is ''", func() {
			it("does not set match", func() {
				existingDeprecationDates := DeprecationDates{}
				newDepDeprecationDate.Match = ""
				updatedDeprecationDates, err := existingDeprecationDates.Update(newDepDeprecationDate)
				require.NoError(t, err)
				assert.Equal(t, DeprecationDates{
					{Name: name1, VersionLine: versionLine1, Date: deprecationDate1, Link: deprecationLink, Match: ""},
				}, updatedDeprecationDates)
			})
		})

		when("version line is latest", func() {
			it("does not update deprecation dates ", func() {
				deprecationDates := DeprecationDates{
					{Name: name1, VersionLine: versionLine1},
					{Name: name2, VersionLine: versionLine2},
				}
				newDepDeprecationDate.VersionLine = "latest"
				updatedDeprecationDates, err := deprecationDates.Update(newDepDeprecationDate)
				assert.Equal(t, deprecationDates, updatedDeprecationDates)
				assert.NoError(t, err)
			})
		})
	})

	when("NewDependencyDeprecationDate", func() {
		deprecationDateString := "2019-01-01"
		link := "fake-link"
		name := "fake-name"
		line := "fake-line"
		match := "fake-match"

		when("deprecation date is not in the correct format", func() {
			it("returns an error", func() {
				date := "invalid-date"
				_, err := NewDependencyDeprecationDate(date, link, name, line, match)
				assert.EqualError(t, err, `could not parse date 'invalid-date', must be in format YYYY-MM-DD`)
			})
		})

		when("name is empty", func() {
			it("returns an error", func() {
				_, err := NewDependencyDeprecationDate(deprecationDateString, link, "", line, match)
				assert.Error(t, err)
			})
		})

		when("line is empty", func() {
			it("returns an error", func() {
				_, err := NewDependencyDeprecationDate(deprecationDateString, link, name, "", match)
				assert.Error(t, err)
			})
		})
	})

}
