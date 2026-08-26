package watchers

import (
	"fmt"
	"regexp"

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
	versionMap := make(map[string]bool)

	// Scrape archive page for older versions (old-style zip links with -b<build> suffix)
	if err := w.scrapeArchivePage(versionMap); err != nil {
		return nil, err
	}

	// Scrape main download page for current version (installer redirect links)
	if err := w.scrapeCurrentVersion(versionMap); err != nil {
		return nil, err
	}

	var versions []base.Internal
	for v := range versionMap {
		versions = append(versions, base.Internal{Ref: v})
	}

	return base.SortVersions(versions), nil
}

func (w *YourKitWatcher) scrapeArchivePage(versionMap map[string]bool) error {
	resp, err := w.client.Get("https://www.yourkit.com/download/archive.jsp")
	if err != nil {
		return fmt.Errorf("fetching archive page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("unexpected status code %d fetching archive page", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return fmt.Errorf("parsing archive HTML: %w", err)
	}

	// Old-style links: .../YourKit-JavaProfiler-2025.9-b191-x64.zip
	pattern := regexp.MustCompile(`.+/YourKit-JavaProfiler-([\d]{4})\.([\d]{1,2})-b([\d]+)-x64\.zip`)

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

	return nil
}

func (w *YourKitWatcher) scrapeCurrentVersion(versionMap map[string]bool) error {
	resp, err := w.client.Get("https://www.yourkit.com/download/")
	if err != nil {
		return fmt.Errorf("fetching downloads page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("unexpected status code %d fetching downloads page", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return fmt.Errorf("parsing downloads HTML: %w", err)
	}

	// The page contains "Version: 2026.3" and "Build: #176" as separate text nodes.
	// Collect the full text and extract both values.
	pageText := doc.Text()

	versionPattern := regexp.MustCompile(`Version:\s*([\d]{4}\.[\d]{1,2})`)
	buildPattern := regexp.MustCompile(`Build:\s*#([\d]+)`)

	versionMatches := versionPattern.FindStringSubmatch(pageText)
	buildMatches := buildPattern.FindStringSubmatch(pageText)

	if versionMatches != nil && buildMatches != nil {
		version := fmt.Sprintf("%s.%s", versionMatches[1], buildMatches[1])
		versionMap[version] = true
	}

	return nil
}

func (w *YourKitWatcher) In(ref string) (base.Release, error) {
	v, err := semver.Parse(ref)
	if err != nil {
		return base.Release{}, fmt.Errorf("parsing version: %w", err)
	}

	// Try new-style URL first (2026+): download.yourkit.com/yjp/YEAR.MINOR.PATCH/YourKit-Java-Profiler-...
	newURL := fmt.Sprintf("https://download.yourkit.com/yjp/%d.%d.%d/YourKit-Java-Profiler-%d.%d.%d-x64.zip",
		v.Major, v.Minor, v.Patch, v.Major, v.Minor, v.Patch)
	resp, err := w.client.GetRaw(newURL, nil)
	if err == nil {
		resp.Body.Close()
		if resp.StatusCode == 200 {
			return base.Release{Ref: ref, URL: newURL}, nil
		}
	}

	// Fall back to old-style URL: archive.yourkit.com/yjp/YEAR.MINOR/YourKit-JavaProfiler-...-b<build>-x64.zip
	oldURL := fmt.Sprintf("https://archive.yourkit.com/yjp/%d.%d/YourKit-JavaProfiler-%d.%d-b%d-x64.zip",
		v.Major, v.Minor, v.Major, v.Minor, v.Patch)
	return base.Release{Ref: ref, URL: oldURL}, nil
}

