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
	binaryBuilds, err := NewBuildInformation(filePath)
	if err != nil {
		return DependencyDiff{}, errors.Wrap(err, "failed to get binary builds story and date")
	}
	log.Printf("Upstream Dependency Released: %v\n", binaryBuilds.CreatedAt)

	githubRelease, err := NewGithubRelease(flags.organization, flags.product, flags.githubToken, binaryBuilds.TrackerStoryID)
	if err != nil {
		return DependencyDiff{}, errors.Wrap(err, "failed to get github release date")
	} else if !githubRelease.Released {
		return DependencyDiff{}, nil
	}
	log.Printf("Dependency Released on Github: %v\n", githubRelease.ReleasedAt)

	passedThreshold := false
	daysToGithub := DaysBetweenDates(binaryBuilds.CreatedAt, githubRelease.ReleasedAt)
	log.Printf("It took %d day(s) for %s %s to get released on github", daysToGithub, dependency, version)
	if daysToGithub > DaysReleasedThreshold {
		passedThreshold = true
		log.Printf("WARNING!!! Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
	}

	var pivnetRelease Release
	if !flags.skipPivnet {
		pivnetRelease, err = NewPivnetRelease(flags.product, strings.TrimPrefix(githubRelease.ReleaseName, "v"))
		if err != nil {
			return DependencyDiff{}, errors.Wrap(err, "failed to get pivnet release date")
		}
		log.Printf("Dependency Released on Pivnet: %v\n", pivnetRelease)

		daysToPivnet := DaysBetweenDates(binaryBuilds.CreatedAt, pivnetRelease.ReleasedAt)
		log.Printf("It took %d day(s) for %s %s to get released on pivnet", daysToPivnet, dependency, version)
		if daysToGithub > DaysReleasedThreshold {
			passedThreshold = true
			log.Printf("WARNING!!! Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
		}
	}

	return DependencyDiff{
		Name:                dependency,
		Version:             version,
		Product:             flags.product,
		UpstreamReleaseTime: binaryBuilds.CreatedAt,
		GithubReleaseTime:   githubRelease.ReleasedAt,
		PivnetReleaseTime:   pivnetRelease.ReleasedAt,
		DaysToRelease:       daysToGithub,
		PassedThreshold:     passedThreshold,
	}, nil
}

func DependencyDiffsFromManifest(manifest utils.ManifestYAML, depsToSkip map[string]bool) ([]DependencyDiff, error) {
	var deps []DependencyDiff
	for _, dep := range manifest.Dependencies {
		if depsToSkip[dep.Name] {
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
