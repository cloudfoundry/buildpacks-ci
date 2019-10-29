package main

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/blang/semver"
)

var (
	latest = "latest"
)

func RemoveOldDeps(deps []Dependency, depID, versionLine string, keepN int) ([]Dependency, error) {
	if keepN <= 0 {
		return nil, errors.New("please specify a valid number of versions (>0) to retain")
	}

	var retainedDeps []Dependency
	retainedPerStack := map[string]int{}

	versionLineConstraint, err := getVersionLineConstraint(versionLine)
	if err != nil {
		return nil, err
	}

	for i := len(deps) - 1; i >= 0; i-- {
		dep := deps[i]
		depVersion, err := semver.Parse(dep.Version)
		if err != nil {
			return nil, err
		}

		differentDep := dep.ID != depID
		differentVersionLine := !versionLineConstraint(depVersion)
		haveNotRetainedNForStack := retainedPerStack[dep.Stacks[0]] < keepN

		if differentDep || differentVersionLine {
			retainedDeps = append(retainedDeps, dep)
		} else if haveNotRetainedNForStack {
			retainedDeps = append(retainedDeps, dep)
			retainedPerStack[dep.Stacks[0]]++
		}
	}

	sort.Slice(retainedDeps, sortDependencies(retainedDeps))
	return retainedDeps, nil
}

func getVersionRange(versionLine string) string {
	return strings.Replace(versionLine, ".x.x", ".x", 1)
}

func getVersionLineConstraint(versionLine string) (semver.Range, error) {
	if versionLine == latest {
		return semver.ParseRange(">=0.0.0")
	}

	versionLine = getVersionRange(versionLine)

	microsoftVersionRegexp := regexp.MustCompile(`([0-9]+)\.([0-9]+)\.([0-9]+)x`)
	matches := microsoftVersionRegexp.FindAllStringSubmatch(versionLine, -1)
	if len(matches) > 0 {
		return getMicrosoftVersionLineConstraint(matches)
	}

	return semver.ParseRange(versionLine)
}

func getMicrosoftVersionLineConstraint(matches [][]string) (semver.Range, error) {
	majorVersion := matches[0][1]
	minorVersion := matches[0][2]
	patchVersion, err := strconv.Atoi(matches[0][3])
	if err != nil {
		return nil, err
	}
	minPatchVersion := fmt.Sprintf("%d00", patchVersion)
	maxPatchVersion := fmt.Sprintf("%d00", patchVersion+1)

	return semver.ParseRange(fmt.Sprintf(
		">=%s.%s.%s <%s.%s.%s",
		majorVersion, minorVersion, minPatchVersion,
		majorVersion, minorVersion, maxPatchVersion,
	))
}
