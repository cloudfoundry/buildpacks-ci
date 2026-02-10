package watchers

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type GithubTagsWatcher struct {
	client base.HTTPClient
	repo   string
}

type githubTag struct {
	Name   string       `json:"name"`
	Commit githubCommit `json:"commit"`
}

type githubCommit struct {
	SHA string `json:"sha"`
}

type GithubTag struct {
	Ref          string
	URL          string
	GitCommitSHA string
	SHA256       string
}

func NewGithubTagsWatcher(client base.HTTPClient, repo string) *GithubTagsWatcher {
	return &GithubTagsWatcher{
		client: client,
		repo:   repo,
	}
}

func (w *GithubTagsWatcher) Check(tagRegex string) ([]base.Internal, error) {
	tags, err := w.matchedTags(tagRegex)
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, tag := range tags {
		internals = append(internals, base.Internal{Ref: tag.Name})
	}

	sort.Slice(internals, func(i, j int) bool {
		vi, err1 := semver.Parse(internals[i].Ref)
		vj, err2 := semver.Parse(internals[j].Ref)
		if err1 != nil || err2 != nil {
			return internals[i].Ref < internals[j].Ref
		}
		return vi.LessThan(vj)
	})

	return internals, nil
}

func (w *GithubTagsWatcher) In(ref string) (GithubTag, error) {
	tags, err := w.tags()
	if err != nil {
		return GithubTag{}, err
	}

	for _, tag := range tags {
		if tag.Name == ref {
			url := fmt.Sprintf("https://github.com/%s/archive/%s.tar.gz", w.repo, tag.Commit.SHA)
			sha256, err := base.GetSHA256(w.client, url)
			if err != nil {
				return GithubTag{}, fmt.Errorf("calculating SHA256: %w", err)
			}

			return GithubTag{
				Ref:          tag.Name,
				URL:          url,
				GitCommitSHA: tag.Commit.SHA,
				SHA256:       sha256,
			}, nil
		}
	}

	return GithubTag{}, fmt.Errorf("could not find data for version %s", ref)
}

func (w *GithubTagsWatcher) MatchedTags(tagRegex string) ([]githubTag, error) {
	return w.matchedTags(tagRegex)
}

func (w *GithubTagsWatcher) matchedTags(tagRegex string) ([]githubTag, error) {
	tags, err := w.tags()
	if err != nil {
		return nil, err
	}

	re, err := regexp.Compile(tagRegex)
	if err != nil {
		return nil, fmt.Errorf("compiling regex: %w", err)
	}

	var matched []githubTag
	for _, tag := range tags {
		if re.MatchString(tag.Name) {
			matched = append(matched, tag)
		}
	}

	return matched, nil
}

func (w *GithubTagsWatcher) tags() ([]githubTag, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/tags?per_page=1000", w.repo)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching tags: %w", err)
	}
	defer resp.Body.Close()

	var tags []githubTag
	if err := json.NewDecoder(resp.Body).Decode(&tags); err != nil {
		return nil, fmt.Errorf("decoding tags: %w", err)
	}

	return tags, nil
}
