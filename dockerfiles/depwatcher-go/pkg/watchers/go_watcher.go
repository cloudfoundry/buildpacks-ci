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

type GoWatcher struct {
	client base.HTTPClient
}

type GoRelease struct {
	Ref    string
	URL    string
	SHA256 string
}

func NewGoWatcher(client base.HTTPClient) *GoWatcher {
	return &GoWatcher{client: client}
}

func (w *GoWatcher) Check() ([]base.Internal, error) {
	releases, err := w.getReleases()
	if err != nil {
		return nil, err
	}

	var internals []base.Internal
	for _, r := range releases {
		internals = append(internals, base.Internal{Ref: r.Ref})
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

func (w *GoWatcher) In(ref string) (GoRelease, error) {
	releases, err := w.getReleases()
	if err != nil {
		return GoRelease{}, err
	}

	for _, r := range releases {
		if r.Ref == ref {
			return r, nil
		}
	}

	return GoRelease{}, fmt.Errorf("could not find data for version %s", ref)
}

func (w *GoWatcher) getReleases() ([]GoRelease, error) {
	resp, err := w.client.Get("https://go.dev/dl/")
	if err != nil {
		return nil, fmt.Errorf("fetching go.dev/dl: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	versionRegex := regexp.MustCompile(`go([\d\.]+)\.src`)
	var releases []GoRelease

	doc.Find("tr").Each(func(i int, tr *goquery.Selection) {
		tds := tr.Find("td")
		if tds.Length() < 6 {
			return
		}

		firstTd := tds.Eq(0)
		if !strings.Contains(firstTd.Text(), "Source") {
			return
		}

		link := firstTd.Find("a")
		href, exists := link.Attr("href")
		if !exists {
			return
		}

		parts := strings.Split(href, "/")
		if len(parts) == 0 {
			return
		}
		releaseName := parts[len(parts)-1]

		matches := versionRegex.FindStringSubmatch(releaseName)
		if len(matches) < 2 {
			return
		}

		version := matches[1]
		url := fmt.Sprintf("https://dl.google.com/go/%s", releaseName)

		sixthTd := tds.Eq(5)
		sha256 := strings.TrimSpace(sixthTd.Find("tt").Text())

		releases = append(releases, GoRelease{
			Ref:    version,
			URL:    url,
			SHA256: sha256,
		})
	})

	return releases, nil
}
