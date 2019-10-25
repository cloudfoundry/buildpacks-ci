package main

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strconv"

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

		differentdep := dep.ID != depID
		differentVersionLine := !versionLineConstraint(depVersion)
		haveNotRetainedNForStack := retainedPerStack[dep.Stacks[0]] < keepN

		if differentdep || differentVersionLine {
			retainedDeps = append(retainedDeps, dep)
		} else if haveNotRetainedNForStack {
			retainedDeps = append(retainedDeps, dep)
			retainedPerStack[dep.Stacks[0]]++
		}
	}

	sort.Slice(retainedDeps, sortDeps(retainedDeps))

	return retainedDeps, nil
}

func getVersionLineConstraint(versionLine string) (semver.Range, error) {
	if versionLine == latest {
		return semver.ParseRange(">=0.0.0")
	}

	microsoftVersionRegexp := regexp.MustCompile(`([0-9]+)\.([0-9]+)\.([0-9]+)x`)
	matches := microsoftVersionRegexp.FindAllStringSubmatch(versionLine, -1)
	if len(matches) > 0 {
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

	return semver.ParseRange(versionLine)
}
