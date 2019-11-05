package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/pivotal-cf/go-pivnet/v2/logshim"

	"github.com/pivotal-cf/go-pivnet/v2"

	"github.com/google/go-github/github"
	"github.com/pkg/errors"
	"golang.org/x/oauth2"
)

var flags struct {
	githubToken string
}

func main() {
	flag.StringVar(&flags.githubToken, "github-token", "", "github token to authenticate")
	flag.Parse()

	if err := run(); err != nil {
		log.Fatalf("failed to run: %s", err)
	}
	log.Println("succesfully ran")
}

// Problem Statement:
// Display in output of some sort, the time difference between ruby-2.6.5 was released (Oct 1)
// and when it was released on github
// as well as pivnet
// output the date difference
func run() error {
	upstreamDependencyReleased, err := FileDate("/Users/pivotal/workspace/public-buildpacks-ci-robots/binary-builds-new/ruby/2.6.5.json")
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Upstream Dependency Released: %v\n", upstreamDependencyReleased)

	org := "cloudfoundry"
	repo := "ruby-buildpack"
	storyID := "168867584"
	_, releasedOnGithub, err := FindGithubReleaseOfStory(org, repo, storyID, flags.githubToken)
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Dependency Released on Github: %v\n", releasedOnGithub)

	releasedOnPivnet, err := FindPivnetReleaseDate("ruby-buildpack", "1.8.0")
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Printf("Dependency Released on Pivnet: %v\n", releasedOnPivnet)

	return nil
}

func FileDate(path string) (time.Time, error) {
	fileDir := filepath.Dir(path)
	fileName := filepath.Base(path)

	//Running git log -1 --format="%aI" --reverse public-buildpacks-ci-robots/binary-builds-new/ruby/2.6.5.json
	cmd := exec.Command("git", "log", "-1", "--format=\"%aI\"", "--reverse", fileName)
	cmd.Dir = fileDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return time.Time{}, errors.Wrap(err, "failed to run `git log`")
	}
	timeString := strings.TrimSpace(string(bytes.ReplaceAll(output, []byte("\""), []byte(""))))

	fileDate, err := time.Parse(time.RFC3339, timeString)
	if err != nil {
		return time.Time{}, errors.Wrap(err, "failed to parse the date")
	}
	return fileDate, nil
}

func FindGithubReleaseOfStory(org, repo, storyID, githubToken string) (string, time.Time, error) {
	ctx := context.Background()
	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: githubToken},
	)
	tc := oauth2.NewClient(ctx, ts)
	client := github.NewClient(tc)
	opts := &github.ListOptions{}

	for {
		releases, response, err := client.Repositories.ListReleases(ctx, org, repo, opts)
		if err != nil {
			return "", time.Time{}, errors.Wrap(err, fmt.Sprintf("failed to get releases for %s/%s", org, repo))
		}

		for _, release := range releases {
			if strings.Contains(*release.Body, storyID) {
				return *release.Name, release.PublishedAt.Time, nil
			}
		}

		if response.NextPage == 0 {
			break
		}
		opts.Page = response.NextPage
	}

	return "", time.Time{}, errors.New(fmt.Sprintf("failed to find %s in releases of %s/%s", storyID, org, repo))
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

func CompareDates(dateA, dateB time.Time) int {
	return 0
}
