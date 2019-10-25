package main

import (
	"fmt"
	"sort"
	"time"
)

func UpdateDeprecationDates(
	deprecationDates []DependencyDeprecationDate,
	depName string,
	versionLine string,
	deprecationDateString string,
	deprecationLink string,
	deprecationMatch string,
) ([]DependencyDeprecationDate, error) {

	if deprecationDateString == "null" || deprecationLink == "null" || deprecationDateString == "" || deprecationLink == "" {
		return deprecationDates, nil
	}

	if deprecationMatch == "null" {
		deprecationMatch = ""
	}

	deprecationDate, err := time.Parse("2006-01-02", deprecationDateString)
	if err != nil {
		return nil, fmt.Errorf("could not parse date '%s', must be in format YYYY-MM-DD", deprecationDateString)
	}

	overwroteExistingDate := false

	for i, existingDeprecationDate := range deprecationDates {
		if existingDeprecationDate.Name == depName && existingDeprecationDate.VersionLine == versionLine {
			deprecationDates[i].Date = deprecationDate
			deprecationDates[i].Link = deprecationLink
			deprecationDates[i].Match = deprecationMatch
			overwroteExistingDate = true
			break
		}
	}

	if !overwroteExistingDate {
		deprecationDates = append(deprecationDates, DependencyDeprecationDate{
			Name:        depName,
			VersionLine: versionLine,
			Date:        deprecationDate,
			Link:        deprecationLink,
			Match:       deprecationMatch,
		})
	}

	sort.Slice(deprecationDates, sortDeprecationDates(deprecationDates))

	return deprecationDates, nil
}

func sortDeprecationDates(deprecationDates []DependencyDeprecationDate) func(i, j int) bool {
	return func(i, j int) bool {
		if deprecationDates[i].Name != deprecationDates[j].Name {
			return deprecationDates[i].Name < deprecationDates[j].Name
		}

		return deprecationDates[i].VersionLine < deprecationDates[j].VersionLine
	}
}
