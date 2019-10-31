package main

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/blang/semver"
)

const Latest = "latest"

func getVersionLineConstraint(versionLine string) (semver.Range, error) {
	if versionLine == Latest {
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

func getVersionRange(versionLine string) string {
	return strings.Replace(versionLine, ".x.x", ".x", 1)
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
