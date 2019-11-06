package main

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/pivotal-cf/go-pivnet/v2"
	"github.com/pivotal-cf/go-pivnet/v2/logshim"

	"github.com/google/go-github/github"
	"github.com/pkg/errors"
	"golang.org/x/oauth2"
)

type Release struct {
	Released    bool
	ReleaseName string
	ReleasedAt  time.Time
}

func FindGithubReleaseOfStory(org, product, githubToken string, storyID int) (string, time.Time, bool, error) {
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

	released := false
	for {
		releases, response, err := client.Repositories.ListReleases(ctx, org, product, opts)
		if err != nil {
			return "", time.Time{}, released, errors.Wrap(err, fmt.Sprintf("failed to get releases for %s/%s", org, product))
		}

		for _, release := range releases {
			if strings.Contains(*release.Body, strconv.Itoa(storyID)) {
				released = true
				return *release.Name, release.PublishedAt.Time, released, nil
			}
		}

		if response.NextPage == 0 {
			break
		}
		opts.Page = response.NextPage
	}

	return "", time.Time{}, released, nil
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
