package watchers

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type PythonWatcher struct {
	client base.HTTPClient
}

func NewPythonWatcher(client base.HTTPClient) *PythonWatcher {
	return &PythonWatcher{client: client}
}

func (w *PythonWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://www.python.org/downloads/")
	if err != nil {
		return nil, fmt.Errorf("fetching python downloads page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	var versions []base.Internal
	doc.Find(".release-number a").Each(func(i int, s *goquery.Selection) {
		text := s.Text()
		text = regexp.MustCompile(`^\s*Python\s*`).ReplaceAllString(text, "")
		text = strings.TrimSpace(text)
		if text != "" {
			versions = append(versions, base.Internal{Ref: text})
		}
	})

	if len(versions) == 0 {
		return nil, fmt.Errorf("could not parse python website: no versions found")
	}

	if len(versions) > 50 {
		versions = versions[:50]
	}

	for i, j := 0, len(versions)-1; i < j; i, j = i+1, j-1 {
		versions[i], versions[j] = versions[j], versions[i]
	}

	return versions, nil
}

func (w *PythonWatcher) In(ref string) (base.Release, error) {
	versionSlug := regexp.MustCompile(`\D`).ReplaceAllString(ref, "")
	url := fmt.Sprintf("https://www.python.org/downloads/release/python-%s/", versionSlug)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching python release page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("parsing HTML: %w", err)
	}

	var downloadURL string
	var md5Digest string

	doc.Find("a").Each(func(i int, s *goquery.Selection) {
		if strings.Contains(s.Text(), "Gzipped source tarball") {
			href, exists := s.Attr("href")
			if exists {
				downloadURL = href

				tr := s.ParentsFiltered("tr")
				if tr.Length() > 0 {
					tds := tr.Find("td")
					if tds.Length() >= 8 {
						md5Digest = strings.TrimSpace(tds.Eq(7).Text())
					} else if tds.Length() >= 7 {
						md5Digest = strings.TrimSpace(tds.Eq(6).Text())
					}
				}
			}
		}
	})

	if downloadURL == "" {
		return base.Release{}, fmt.Errorf("could not find download URL for Python %s", ref)
	}

	if md5Digest == "" {
		return base.Release{}, fmt.Errorf("could not find MD5 digest for Python %s", ref)
	}

	sha256, err := base.GetSHA256(w.client, downloadURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("calculating SHA256: %w", err)
	}

	return base.Release{
		Ref:    ref,
		URL:    downloadURL,
		SHA256: sha256,
	}, nil
}
