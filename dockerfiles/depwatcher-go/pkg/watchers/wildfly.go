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

type WildflyWatcher struct {
	client base.HTTPClient
}

func NewWildflyWatcher(client base.HTTPClient) *WildflyWatcher {
	return &WildflyWatcher{client: client}
}

func (w *WildflyWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://wildfly.org/downloads/")
	if err != nil {
		return nil, fmt.Errorf("fetching downloads page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code %d fetching https://wildfly.org/downloads/", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	pattern := regexp.MustCompile(`([\d]+)\.([\d]+)\.([\d]+)\.Final`)
	var versions []base.Internal

	doc.Find(".version-id").Each(func(i int, s *goquery.Selection) {
		text := strings.TrimSpace(s.Text())
		matches := pattern.FindStringSubmatch(text)
		if matches != nil && len(matches) >= 4 {
			version := fmt.Sprintf("%s.%s.%s-Final", matches[1], matches[2], matches[3])
			versions = append(versions, base.Internal{Ref: version})
		}
	})

	return w.sortVersions(versions), nil
}

func (w *WildflyWatcher) In(ref string) (base.Release, error) {
	// Parse version to construct download URL
	// Version format: "26.1.0-Final" -> need to convert to "26.1.0.Final"
	parts := strings.Split(ref, "-")
	if len(parts) != 2 {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}

	urlVersion := fmt.Sprintf("%s.%s", parts[0], parts[1])
	filename := fmt.Sprintf("wildfly-%s.tar.gz", urlVersion)
	url := fmt.Sprintf("https://download.jboss.org/wildfly/%s/%s", urlVersion, filename)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}

func (w *WildflyWatcher) sortVersions(internals []base.Internal) []base.Internal {
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
