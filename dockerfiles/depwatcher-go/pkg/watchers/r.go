package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

// RWatcher watches for new R language releases from CRAN.
type RWatcher struct {
	client base.HTTPClient
}

// NewRWatcher creates a new RWatcher.
func NewRWatcher(client base.HTTPClient) *RWatcher {
	return &RWatcher{client: client}
}

// Check retrieves the latest R releases from CRAN.
// It scrapes the R-4 base directory and returns the last 10 versions sorted by semver.
func (w *RWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://cran.r-project.org/src/base/R-4/")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch R releases: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse HTML: %w", err)
	}

	pattern := regexp.MustCompile(`^R-([\d\.]+)\.tar\.gz$`)
	var versions []string

	doc.Find("td a").Each(func(_ int, s *goquery.Selection) {
		href, exists := s.Attr("href")
		if !exists {
			return
		}

		matches := pattern.FindStringSubmatch(href)
		if len(matches) > 1 {
			versions = append(versions, matches[1])
		}
	})

	if len(versions) == 0 {
		return nil, fmt.Errorf("could not parse R releases from CRAN website")
	}

	result := make([]base.Internal, len(versions))
	for i, version := range versions {
		result[i] = base.Internal{Ref: version}
	}

	sort.Slice(result, func(i, j int) bool {
		vi, err1 := semver.Parse(result[i].Ref)
		vj, err2 := semver.Parse(result[j].Ref)
		if err1 != nil || err2 != nil {
			return result[i].Ref < result[j].Ref
		}
		return vi.LessThan(vj)
	})

	if len(result) > 10 {
		result = result[len(result)-10:]
	}

	return result, nil
}

// In retrieves details for a specific R version.
// It constructs the download URL based on the major version and computes the SHA256 checksum.
func (w *RWatcher) In(ref string) (base.Release, error) {
	if ref == "" {
		return base.Release{}, fmt.Errorf("invalid version format: version cannot be empty")
	}

	parts := strings.Split(ref, ".")
	if len(parts) == 0 || parts[0] == "" {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}

	major := parts[0]
	url := fmt.Sprintf("https://cran.r-project.org/src/base/R-%s/R-%s.tar.gz", major, ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download R release: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256sum,
	}, nil
}
