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

type JProfilerWatcher struct {
	client base.HTTPClient
}

func NewJProfilerWatcher(client base.HTTPClient) *JProfilerWatcher {
	return &JProfilerWatcher{client: client}
}

func (w *JProfilerWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://www.ej-technologies.com/jprofiler/changelog")
	if err != nil {
		return nil, fmt.Errorf("fetching changelog: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code %d fetching https://www.ej-technologies.com/jprofiler/changelog", resp.StatusCode)
	}

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	pattern := regexp.MustCompile(`^Release ([\d]+)\.([\d]+)\.([\d]+).*$`)
	var versions []base.Internal

	doc.Find("div.release-heading").Each(func(i int, s *goquery.Selection) {
		text := strings.TrimSpace(s.Text())
		matches := pattern.FindStringSubmatch(text)
		if matches != nil && len(matches) >= 4 {
			version := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
			versions = append(versions, base.Internal{Ref: version})
		}
	})

	return w.sortVersions(versions), nil
}

func (w *JProfilerWatcher) In(ref string) (base.Release, error) {
	// Parse version to construct filename and URL
	v, err := semver.Parse(ref)
	if err != nil {
		return base.Release{}, fmt.Errorf("parsing version: %w", err)
	}

	// Filename format: jprofiler_linux_<major>_<minor>[_<patch>].tar.gz
	filename := fmt.Sprintf("jprofiler_linux_%d_%d", v.Major, v.Minor)
	if v.Patch != 0 {
		filename = fmt.Sprintf("%s_%d", filename, v.Patch)
	}
	filename = fmt.Sprintf("%s.tar.gz", filename)

	url := fmt.Sprintf("https://download-gcdn.ej-technologies.com/jprofiler/%s", filename)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}

func (w *JProfilerWatcher) sortVersions(internals []base.Internal) []base.Internal {
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
