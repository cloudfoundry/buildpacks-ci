package watchers

import (
	"fmt"
	"io"
	"regexp"
	"sort"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type JRubyWatcher struct {
	client base.HTTPClient
}

func NewJRubyWatcher(client base.HTTPClient) *JRubyWatcher {
	return &JRubyWatcher{client: client}
}

// Check fetches all available JRuby versions from jruby.org download page
func (w *JRubyWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://www.jruby.org/download")
	if err != nil {
		return nil, fmt.Errorf("fetching jruby download page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	// Pattern: https://repo1.maven.org/maven2/org/jruby/jruby-dist/X.Y.Z/jruby-dist-X.Y.Z-src.zip
	versionRe := regexp.MustCompile(`https://repo1\.maven\.org/maven2/org/jruby/jruby-dist/([\d.]+)/jruby-dist-([\d.]+)-src\.zip`)

	versionMap := make(map[string]bool)
	var versions []base.Internal

	doc.Find("a").Each(func(i int, s *goquery.Selection) {
		href, exists := s.Attr("href")
		if !exists {
			return
		}

		matches := versionRe.FindStringSubmatch(href)
		if len(matches) > 1 {
			version := matches[1]
			if !versionMap[version] {
				versionMap[version] = true
				versions = append(versions, base.Internal{Ref: version})
			}
		}
	})

	if len(versions) == 0 {
		return nil, fmt.Errorf("could not parse jruby website: no versions found")
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

// In fetches detailed information about a specific JRuby version
func (w *JRubyWatcher) In(ref string) (base.Release, error) {
	shaURL := fmt.Sprintf("https://repo1.maven.org/maven2/org/jruby/jruby-dist/%s/jruby-dist-%s-src.zip.sha256", ref, ref)

	resp, err := w.client.Get(shaURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching SHA256 for JRuby %s: %w", ref, err)
	}
	defer resp.Body.Close()

	shaBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("reading SHA256 response: %w", err)
	}

	sha256 := strings.TrimSpace(string(shaBytes))
	if sha256 == "" {
		return base.Release{}, fmt.Errorf("empty SHA256 for JRuby %s", ref)
	}

	downloadURL := fmt.Sprintf("https://repo1.maven.org/maven2/org/jruby/jruby-dist/%s/jruby-dist-%s-src.zip", ref, ref)

	return base.Release{
		Ref:    ref,
		URL:    downloadURL,
		SHA256: sha256,
	}, nil
}
