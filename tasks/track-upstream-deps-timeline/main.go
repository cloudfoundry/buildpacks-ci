package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/pivotal-cf/go-pivnet/v2/logshim"

	"github.com/pivotal-cf/go-pivnet/v2"

	"github.com/google/go-github/github"
	"github.com/pkg/errors"
	"golang.org/x/oauth2"
)

var flags struct {
	githubToken  string
	dependency   string
	version      string
	organization string
	repo         string
}

type BinaryBuildsFile struct {
	TrackerStoryID int `json:"tracker_story_id"`
}

// Problem Statement:
// Display the time difference between the release of a dependency (ruby-2.6.5)
// when it was released on github
// and when it was released on pivnet

const DaysReleasedThreshold = 7

func main() {
	parseFlags()
	if err := run(); err != nil {
		log.Fatalf("failed to run: %s", err)
	}
	log.Println("succesfully ran")
}

func parseFlags() {
	flag.StringVar(&flags.githubToken, "github-token", "", "github token to authenticate")
	flag.StringVar(&flags.dependency, "dependency", "", "upstream dependency")
	flag.StringVar(&flags.version, "version", "", "version of dependency")
	flag.StringVar(&flags.organization, "organization", "cloudfoundry", "github organization of output")
	flag.StringVar(&flags.repo, "repo", "", "repo of output")
	flag.Parse()
}

func run() error {
	filePath := fmt.Sprintf("/Users/davidfreilich/workspace/public-buildpacks-ci-robots/binary-builds-new/%s/%s.json", flags.dependency, flags.version)
	binaryBuilds, upstreamDependencyReleased, err := GetBinaryBuildsStoryAndDate(filePath)
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Upstream Dependency Released: %v\n", upstreamDependencyReleased)

	githubReleaseVersion, githubReleaseDate, err := FindGithubReleaseOfStory(flags.organization, flags.repo, flags.githubToken, binaryBuilds.TrackerStoryID)
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Dependency Released on Github: %v\n", githubReleaseDate)

	pivnetReleaseDate, err := FindPivnetReleaseDate(flags.repo, strings.TrimPrefix(githubReleaseVersion, "v"))
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Dependency Released on Pivnet: %v\n", pivnetReleaseDate)

	daysToGithub := DaysBetweenDates(upstreamDependencyReleased, githubReleaseDate)
	log.Printf("It took %d day(s) for %s %s to get released on github", daysToGithub, flags.dependency, flags.version)
	if daysToGithub > DaysReleasedThreshold {
		log.Printf("Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
	}
	daysToPivnet := DaysBetweenDates(upstreamDependencyReleased, pivnetReleaseDate)
	log.Printf("It took %d day(s) for %s %s to get released on pivnet", daysToPivnet, flags.dependency, flags.version)
	if daysToGithub > DaysReleasedThreshold {
		log.Printf("Failed to meet our desired threshold of %d days", DaysReleasedThreshold)
	}
	return nil
}

func GetBinaryBuildsStoryAndDate(path string) (BinaryBuildsFile, time.Time, error) {
	fileDir := filepath.Dir(path)
	fileName := filepath.Base(path)

	binaryBuilds := BinaryBuildsFile{}
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		return BinaryBuildsFile{}, time.Time{}, errors.Wrap(err, fmt.Sprintf("failed to read file at: %s", path))
	}
	if err := json.Unmarshal(contents, &binaryBuilds); err != nil {
		return BinaryBuildsFile{}, time.Time{}, errors.Wrap(err, fmt.Sprintf("failed to parse binary build from %s", string(contents)))
	}

	//Running git log -1 --format="%aI" --reverse public-buildpacks-ci-robots/binary-builds-new/ruby/2.6.5.json
	cmd := exec.Command("git", "log", "-1", "--format=\"%aI\"", "--reverse", fileName)
	cmd.Dir = fileDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return BinaryBuildsFile{}, time.Time{}, errors.Wrap(err, "failed to run `git log`")
	}
	timeString := strings.TrimSpace(string(bytes.ReplaceAll(output, []byte("\""), []byte(""))))

	fileDate, err := time.Parse(time.RFC3339, timeString)
	if err != nil {
		return BinaryBuildsFile{}, time.Time{}, errors.Wrap(err, "failed to parse the date")
	}
	return binaryBuilds, fileDate, nil
}

func FindGithubReleaseOfStory(org, repo, githubToken string, storyID int) (string, time.Time, error) {
	var tc *http.Client
	ctx := context.Background()

	if githubToken != "" {
		ts := oauth2.StaticTokenSource(
			&oauth2.Token{AccessToken: githubToken},
		)
		tc = oauth2.NewClient(ctx, ts)
	}
	client := github.NewClient(tc)
	opts := &github.ListOptions{}

	for {
		releases, response, err := client.Repositories.ListReleases(ctx, org, repo, opts)
		if err != nil {
			return "", time.Time{}, errors.Wrap(err, fmt.Sprintf("failed to get releases for %s/%s", org, repo))
		}

		for _, release := range releases {
			if strings.Contains(*release.Body, strconv.Itoa(storyID)) {
				return *release.Name, release.PublishedAt.Time, nil
			}
		}

		if response.NextPage == 0 {
			break
		}
		opts.Page = response.NextPage
	}

	return "", time.Time{}, errors.New(fmt.Sprintf("failed to find %v in releases of %s/%s", storyID, org, repo))
}

func FindPivnetReleaseDate(product, releaseName string) (time.Time, error) {
	config := pivnet.ClientConfig{
		Host: pivnet.DefaultHost,
	}
	token := pivnet.NewAccessTokenOrLegacyToken("", "", true)
	client := pivnet.NewClient(token, config, logshim.LogShim{})

	releases, err := client.Releases.List(product)
	if err != nil {
		return time.Time{}, errors.Wrap(err, fmt.Sprintf("failed to get releases of %s", product))
	}
	for _, release := range releases {
		if release.Version == releaseName {
			releaseTime, err := time.Parse(time.RFC3339, release.SoftwareFilesUpdatedAt)
			if err != nil {
				return time.Time{}, errors.Wrap(err, "failed to parse time from release")
			}
			return releaseTime, nil
		}
	}

	return time.Time{}, errors.New("this version hasn't been released yet")
}

func DaysBetweenDates(dateA, dateB time.Time) int {
	diff := dateB.Sub(dateA)
	return int(diff.Hours() / 24)
}
