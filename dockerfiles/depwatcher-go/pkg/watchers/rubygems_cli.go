package watchers

import (
	"fmt"
	"regexp"
	"sort"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type RubygemsCLIWatcher struct {
	client base.HTTPClient
}

func NewRubygemsCLIWatcher(client base.HTTPClient) *RubygemsCLIWatcher {
	return &RubygemsCLIWatcher{client: client}
}

// Check scrapes the RubyGems download page and extracts all available versions.
func (w *RubygemsCLIWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://rubygems.org/pages/download")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch rubygems download page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse HTML: %w", err)
	}

	versionRegex := regexp.MustCompile(`/rubygems-(.*)\.tgz$`)
	var versions []base.Internal

	doc.Find("div#formats a:contains('tgz')").Each(func(i int, s *goquery.Selection) {
		href, exists := s.Attr("href")
		if !exists {
			return
		}

		matches := versionRegex.FindStringSubmatch(href)
		if len(matches) == 2 {
			versions = append(versions, base.Internal{Ref: matches[1]})
		}
	})

	if len(versions) == 0 {
		return nil, fmt.Errorf("could not parse rubygems download website")
	}

	sort.Slice(versions, func(i, j int) bool {
		vi, err1 := semver.Parse(versions[i].Ref)
		vj, err2 := semver.Parse(versions[j].Ref)
		if err1 != nil || err2 != nil {
			return versions[i].Ref < versions[j].Ref
		}
		return vi.LessThan(vj)
	})

	return versions, nil
}

// In returns the download URL for a specific RubyGems CLI version.
func (w *RubygemsCLIWatcher) In(version string) (base.Release, error) {
	return base.Release{
		Ref: version,
		URL: fmt.Sprintf("https://rubygems.org/rubygems/rubygems-%s.tgz", version),
	}, nil
}
