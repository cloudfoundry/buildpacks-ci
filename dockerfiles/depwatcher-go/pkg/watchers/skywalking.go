package watchers

import (
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type SkyWalkingWatcher struct {
	client base.HTTPClient
}

func NewSkyWalkingWatcher(client base.HTTPClient) *SkyWalkingWatcher {
	return &SkyWalkingWatcher{client: client}
}

func (w *SkyWalkingWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://skywalking.apache.org/downloads")
	if err != nil {
		return nil, fmt.Errorf("fetching downloads page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	pattern := regexp.MustCompile(`v([\d]+)\.([\d]+)\.([\d]+)`)
	var versions []base.Internal

	// Look for Java Agent card
	doc.Find(".card-body").Each(func(i int, s *goquery.Selection) {
		title := strings.TrimSpace(s.Find(".title-box > .card-title").Text())
		if title == "Java Agent" {
			versionText := strings.TrimSpace(s.Find(".dropdown-header").Text())
			matches := pattern.FindStringSubmatch(versionText)
			if matches != nil && len(matches) >= 4 {
				version := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
				versions = append(versions, base.Internal{Ref: version})
			}
		}
	})

	return w.sortVersions(versions), nil
}

func (w *SkyWalkingWatcher) In(ref string) (base.Release, error) {
	// First, we need to get the actual download URL from Apache's mirror system
	// The URL pattern is: https://www.apache.org/dyn/closer.cgi/skywalking/java-agent/{version}/apache-skywalking-java-agent-{version}.tgz
	mirrorURL := fmt.Sprintf("https://www.apache.org/dyn/closer.cgi/skywalking/java-agent/%s/apache-skywalking-java-agent-%s.tgz", ref, ref)

	resp, err := w.client.Get(mirrorURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching mirror page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("parsing mirror HTML: %w", err)
	}

	// Extract the actual download URL from the mirror page
	var downloadURL string
	doc.Find("div.container p a strong").Each(func(i int, s *goquery.Selection) {
		downloadURL = strings.TrimSpace(s.Text())
	})

	if downloadURL == "" {
		// Fallback to archive URL if mirror page doesn't work
		downloadURL = fmt.Sprintf("https://archive.apache.org/dist/skywalking/java-agent/%s/apache-skywalking-java-agent-%s.tgz", ref, ref)
	}

	return base.Release{
		Ref: ref,
		URL: downloadURL,
	}, nil
}

func (w *SkyWalkingWatcher) sortVersions(internals []base.Internal) []base.Internal {
	sort.Slice(internals, func(i, j int) bool {
		vi, erri := semver.Parse(internals[i].Ref)
		vj, errj := semver.Parse(internals[j].Ref)
		if erri == nil && errj == nil {
			return vi.LessThan(vj)
		}
		return internals[i].Ref < internals[j].Ref
	})
	return internals
}
