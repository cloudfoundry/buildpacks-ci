package main

import (
	"errors"
	"fmt"
	"sort"
	"time"
)

func UpdateDeprecationDates(
	deprecationDates []DependencyDeprecationDate,
	depName string,
	envs EnvVars) ([]DependencyDeprecationDate, error) {

	if envs.DeprecationDate == "null" || envs.DeprecationLink == "null" || envs.DeprecationDate == "" || envs.DeprecationLink == "" {
		return deprecationDates, nil
	}

	if envs.DeprecationMatch == "null" {
		envs.DeprecationMatch = ""
	}

	deprecationDate, err := time.Parse("2006-01-02", envs.DeprecationDate)
	if err != nil {
		return nil, errors.New(fmt.Sprintf("could not parse date '%s', must be in format YYYY-MM-DD", envs.DeprecationDate))
	}

	overwroteExistingDate := false

	for i, existingDeprecationDate := range deprecationDates {
		if existingDeprecationDate.Name == depName && existingDeprecationDate.VersionLine == envs.VersionLine {
			deprecationDates[i].Date = deprecationDate
			deprecationDates[i].Link = envs.DeprecationLink
			deprecationDates[i].Match = envs.DeprecationMatch
			overwroteExistingDate = true
			break
		}
	}

	if !overwroteExistingDate {
		deprecationDates = append(deprecationDates, DependencyDeprecationDate{
			Name:        depName,
			VersionLine: envs.VersionLine,
			Date:        deprecationDate,
			Link:        envs.DeprecationLink,
			Match:       envs.DeprecationMatch,
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
