package watchers

import (
	"fmt"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type CRANWatcher struct {
	client base.HTTPClient
	name   string
}

func NewCRANWatcher(client base.HTTPClient, name string) *CRANWatcher {
	return &CRANWatcher{
		client: client,
		name:   name,
	}
}

// Check retrieves the latest version of a CRAN package.
// It scrapes the package index page and extracts the version from the HTML table.
func (w *CRANWatcher) Check() ([]base.Internal, error) {
	url := fmt.Sprintf("https://cran.r-project.org/web/packages/%s/index.html", w.name)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch CRAN package page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse HTML: %w", err)
	}

	var version string
	doc.Find("td").Each(func(_ int, s *goquery.Selection) {
		text := strings.TrimSpace(s.Text())
		if text == "Version:" {
			nextTd := s.Next()
			if nextTd.Length() > 0 {
				version = strings.TrimSpace(nextTd.Text())
			}
		}
	})

	if version == "" {
		return nil, fmt.Errorf("could not parse %s website: version not found", w.name)
	}

	version = strings.ReplaceAll(version, "-", ".")

	return []base.Internal{{Ref: version}}, nil
}

// In constructs the download URL for a specific version of a CRAN package.
// Special handling: Rserve uses hyphens, other packages use dots for patch versions.
func (w *CRANWatcher) In(ref string) (base.Release, error) {
	parts := strings.Split(ref, ".")
	if len(parts) < 2 {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}

	major := parts[0]
	minor := parts[1]
	patch := ""

	if len(parts) > 2 {
		separator := "."
		if w.name == "Rserve" {
			separator = "-"
		}
		patch = separator + parts[2]
	}

	url := fmt.Sprintf("https://cran.r-project.org/src/contrib/%s_%s.%s%s.tar.gz", w.name, major, minor, patch)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}
