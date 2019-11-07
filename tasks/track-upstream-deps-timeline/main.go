package main

import (
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"time"

	"github.com/cloudfoundry/buildpacks-ci/utils"
	"gopkg.in/yaml.v2"
)

/*
Problem Statement:
Display the time difference between the release of a dependency (ruby-2.6.5)
when it was released on github
and when it was released on pivnet

Usage:
To parse manifest, run:
go run github.com/cloudfoundry/buildpacks-ci/tasks/track-upstream-deps-timeline \
	-manifest-path <PATH_TO_LOCAL_MANIFEST> \
	-product <BUILDPACK_NAME> \
	-github-token <GITHUB_TOKEN> \
	-skip-pivnet <bool - is this product on pivnet or not?>
Sample:
go run github.com/cloudfoundry/buildpacks-ci/tasks/track-upstream-deps-timeline \
	-manifest-path ~/workspace/nodejs-buildpack/manifest.yml \
	-product nodejs-buildpack \
	-github-token REDACTED

To parse an individual dependency, run:
go run github.com/cloudfoundry/buildpacks-ci/tasks/track-upstream-deps-timeline \
	-product <BUILDPACK_NAME> \
	-dependency <DEP> 		  \
	-version <VERSION> 		  \
	-github-token <GITHUB_TOKEN> 		\
	-organization <GITHUB ORG: eg. cloudfoundry> \
	- skip-pivnet <bool - is this product on pivnet or not?>
Sample:
go run github.com/cloudfoundry/buildpacks-ci/tasks/track-upstream-deps-timeline \
	-product nodejs-buildpack \
	-dependency node \
	-version 12.13.0 \
	-organization cloudfoundry

One important assumption that this makes is on the location of public-ci-robots, in order to do a search.
It assumes that it's at /Users/pivotal/workspace/public-buildpacks-ci-robots, for testing on local environments purposes
*/

type Flags struct {
	githubToken  string
	dependency   string
	version      string
	organization string
	product      string
	manifestPath string
	skipPivnet   bool
}

var flags Flags

var DepsToSkip = map[string]bool{
	"openjdk1.8-latest": true, //This was added manually 2 years ago, and isn't in buildpacks-ci-robots
}

func init() {
	flag.StringVar(&flags.githubToken, "github-token", "", "github token to authenticate")
	flag.StringVar(&flags.dependency, "dependency", "", "upstream dependency")
	flag.StringVar(&flags.version, "version", "", "version of dependency")
	flag.StringVar(&flags.organization, "organization", "cloudfoundry", "github organization of output")
	flag.StringVar(&flags.product, "product", "", "product dependency is put into")
	flag.StringVar(&flags.manifestPath, "manifest-path", "", "manifest to load, and iterate over all dependencies")
	flag.BoolVar(&flags.skipPivnet, "skip-pivnet", false, "skip the search for pivnet release date")
}

func main() {
	flag.Parse()
	if err := run(); err != nil {
		log.Fatalf("\nfailed to run: %s", err)
	}
	log.Println("\nsuccesfully ran")
}

func run() error {
	if flags.manifestPath != "" {
		return runOnManifest()
	} else {
		_, err := NewDependencyDiff(flags.dependency, flags.version, flags)
		return err
	}
}

func runOnManifest() error {
	var passedThreshold []DependencyDiff
	var manifest utils.ManifestYAML
	contents, err := ioutil.ReadFile(flags.manifestPath)
	if err != nil {
		return err
	}
	err = yaml.Unmarshal(contents, &manifest)
	if err != nil {
		return err
	}

	diffs, err := DependencyDiffsFromManifest(manifest, DepsToSkip)
	if err != nil {
		return err
	}
	if len(diffs) == 0 {
		return errors.New("didn't find any dependency diffs inside the manifest")
	}

	for _, diff := range diffs {
		if diff.PassedThreshold {
			passedThreshold = append(passedThreshold, diff)
		}
	}

	logDependencyDiffs(passedThreshold, len(diffs))
	return nil
}

func logDependencyDiffs(passedThreshold []DependencyDiff, totalDiffs int) {
	postSLO := len(passedThreshold)
	preSLO := totalDiffs - postSLO
	average := ((preSLO - postSLO) / totalDiffs) * 100

	fmt.Printf("\n\n%d dependencies that were released within our SLO:\n", preSLO)
	fmt.Printf("Found %d dependencies that were released after our SLO:\n\n", postSLO)
	for _, dep := range passedThreshold {
		fmt.Printf("%s v%s in %s took %d days to release\n", dep.Name, dep.Version, dep.Product, dep.DaysToRelease)
	}
	fmt.Printf("We are averaging %d%% below our SLO for %s\n", average, flags.product)
}

func DaysBetweenDates(dateA, dateB time.Time) int {
	diff := dateB.Sub(dateA)
	return int(diff.Hours() / 24)
}
