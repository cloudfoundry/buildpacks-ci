package main

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/cloudfoundry/buildpacks-ci/utils"

	"github.com/pkg/errors"
)

const DaysReleasedThreshold = 7

var DepsToSkip = map[string]bool{
	"openjdk1.8-latest": true, //This was added manually 2 years ago, and isn't in buildpacks-ci-robots
}

type DependencyDiff struct {
	Name                string
	Version             string
	Product             string
	UpstreamReleaseTime time.Time
	GithubReleaseTime   time.Time
	PivnetReleaseTime   time.Time
	DaysToRelease       int
	PassedThreshold     bool
}

func NewDependencyDiff(dependency, version string, flags Flags) (DependencyDiff, error) {
	filePath := fmt.Sprintf("/Users/pivotal/workspace/public-buildpacks-ci-robots/binary-builds-new/%s/%s.json", dependency, version)
	binaryBuilds, err := NewBinaryBuild(filePath)
	if err != nil {
		return DependencyDiff{}, errors.Wrap(err, "failed to get binary builds story and date")
	}
	log.Printf("Upstream Dependency Released: %v\n", binaryBuilds.CreatedAt)

	githubReleaseVersion, githubReleaseDate, released, err := FindGithubReleaseOfStory(flags.organization, flags.product, flags.githubToken, binaryBuilds.TrackerStoryID)
	if err != nil {
		return DependencyDiff{}, errors.Wrap(err, "failed to get github release date")
	} else if !released {
		return DependencyDiff{}, nil
	}
	log.Printf("Dependency Released on Github: %v\n", githubReleaseDate)

	pastThreshold := false
	daysToGithub := DaysBetweenDates(binaryBuilds.CreatedAt, githubReleaseDate)
	log.Printf("It took %d day(s) for %s %s to get released on github", daysToGithub, dependency, version)
	if daysToGithub > DaysReleasedThreshold {
		pastThreshold = true
		log.Printf("WARNING!!! Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
	}

	var pivnetReleaseDate time.Time
	if !flags.skipPivnet {
		pivnetReleaseDate, err = FindPivnetReleaseDate(flags.product, strings.TrimPrefix(githubReleaseVersion, "v"))
		if err != nil {
			return DependencyDiff{}, errors.Wrap(err, "failed to get pivnet release date")
		}
		log.Printf("Dependency Released on Pivnet: %v\n", pivnetReleaseDate)

		daysToPivnet := DaysBetweenDates(binaryBuilds.CreatedAt, pivnetReleaseDate)
		log.Printf("It took %d day(s) for %s %s to get released on pivnet", daysToPivnet, dependency, version)
		if daysToGithub > DaysReleasedThreshold {
			pastThreshold = true
			log.Printf("WARNING!!! Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
		}
	}

	return DependencyDiff{
		Name:                dependency,
		Version:             version,
		Product:             flags.product,
		UpstreamReleaseTime: binaryBuilds.CreatedAt,
		GithubReleaseTime:   githubReleaseDate,
		PivnetReleaseTime:   pivnetReleaseDate,
		DaysToRelease:       daysToGithub,
		PassedThreshold:     pastThreshold,
	}, nil
}

func DependencyDiffsFromManifest(manifest utils.ManifestYAML) ([]DependencyDiff, error) {
	var deps []DependencyDiff
	for _, dep := range manifest.Dependencies {
		if DepsToSkip[dep.Name] {
			continue
		}

		diff, err := NewDependencyDiff(dep.Name, dep.Version, flags)
		if err != nil {
			return []DependencyDiff{}, errors.Wrap(err, fmt.Sprintf("failed to calculate time difference for dependency %s v%s", dep.Name, dep.Version))
		}
		deps = append(deps, diff)
	}
	return deps, nil
}
