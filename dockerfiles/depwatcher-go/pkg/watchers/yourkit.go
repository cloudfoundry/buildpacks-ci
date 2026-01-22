package watchers

import (
	"fmt"
	"regexp"
	"sort"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type YourKitWatcher struct {
	client base.HTTPClient
}

func NewYourKitWatcher(client base.HTTPClient) *YourKitWatcher {
	return &YourKitWatcher{client: client}
}

func (w *YourKitWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://www.yourkit.com/download/")
	if err != nil {
		return nil, fmt.Errorf("fetching downloads page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	pattern := regexp.MustCompile(`.+/YourKit-JavaProfiler-([\d]{4})\.([\d]{1,2})-b([\d]+)-x64\.zip`)
	versionMap := make(map[string]bool)

	doc.Find("a[href]").Each(func(i int, s *goquery.Selection) {
		href, exists := s.Attr("href")
		if !exists {
			return
		}

		matches := pattern.FindStringSubmatch(href)
		if matches != nil && len(matches) >= 4 {
			version := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
			versionMap[version] = true
		}
	})

	var versions []base.Internal
	for v := range versionMap {
		versions = append(versions, base.Internal{Ref: v})
	}

	return w.sortVersions(versions), nil
}

func (w *YourKitWatcher) In(ref string) (base.Release, error) {
	// Parse version to construct filename and URL
	v, err := semver.Parse(ref)
	if err != nil {
		return base.Release{}, fmt.Errorf("parsing version: %w", err)
	}

	// Filename format: YourKit-JavaProfiler-<year>.<minor>-b<build>-x64.zip
	filename := fmt.Sprintf("YourKit-JavaProfiler-%d.%d-b%d-x64.zip", v.Major, v.Minor, v.Patch)
	url := fmt.Sprintf("https://download.yourkit.com/yjp/%d.%d/%s", v.Major, v.Minor, filename)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}

func (w *YourKitWatcher) sortVersions(internals []base.Internal) []base.Internal {
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
