package main

import (
	"errors"
	"fmt"
	"sort"
	"time"
)

type DependencyDeprecationDate struct {
	Date        time.Time
	Link        string
	Name        string
	VersionLine string `toml:"version_line"`
	Match       string `toml:",omitempty"`
}

type DeprecationDates []DependencyDeprecationDate

func NewDependencyDeprecationDate(date, link, name, versionLine, match string) (DependencyDeprecationDate, error) {
	var (
		deprecationDate time.Time
		err             error
	)

	if date != "" && date != "null" {
		deprecationDate, err = time.Parse("2006-01-02", date)
		if err != nil {
			return DependencyDeprecationDate{}, errors.New(fmt.Sprintf("could not parse date '%s', must be in format YYYY-MM-DD", date))
		}
	}

	if name == "" || versionLine == "" {
		return DependencyDeprecationDate{}, errors.New("name and line must not be empty")
	}

	if match == "null" {
		match = ""
	}

	if link == "null" {
		link = ""
	}

	return DependencyDeprecationDate{
		Date:        deprecationDate,
		Link:        link,
		Name:        name,
		VersionLine: versionLine,
		Match:       match,
	}, nil
}

func (d DependencyDeprecationDate) isNull() bool {
	return d.Date == time.Time{} || d.Link == "" || d.VersionLine == "latest"
}

func (deprecationDates DeprecationDates) UpdateDeprecationDatesWithDependency(dep DependencyDeprecationDate) (DeprecationDates, error) {
	if dep.isNull() {
		return deprecationDates, nil
	}

	overwroteExistingDate := false
	for i, existingDeprecationDate := range deprecationDates {
		if existingDeprecationDate.Name == dep.Name && existingDeprecationDate.VersionLine == dep.VersionLine {
			deprecationDates[i] = dep
			overwroteExistingDate = true
			break
		}
	}

	if !overwroteExistingDate {
		deprecationDates = append(deprecationDates, dep)
	}

	sort.Slice(deprecationDates, deprecationDates.Sort())
	return deprecationDates, nil
}

func (deprecationDates DeprecationDates) Sort() func(i, j int) bool {
	return func(i, j int) bool {
		if deprecationDates[i].Name != deprecationDates[j].Name {
			return deprecationDates[i].Name < deprecationDates[j].Name
		}

		return deprecationDates[i].VersionLine < deprecationDates[j].VersionLine
	}
}
