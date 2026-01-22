package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"
	"sort"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type CaApmAgentWatcher struct {
	client base.HTTPClient
}

func NewCaApmAgentWatcher(client base.HTTPClient) *CaApmAgentWatcher {
	return &CaApmAgentWatcher{client: client}
}

// Check retrieves CA APM PHP agent versions from Broadcom artifactory.
// Returns the last 10 versions sorted by semver.
func (w *CaApmAgentWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://packages.broadcom.com/artifactory/apm-agents/")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch CA APM agents page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse HTML: %w", err)
	}

	pattern := regexp.MustCompile(`^CA-APM-PHPAgent-([\d\.]+)_linux\.tar\.gz$`)
	var versions []string

	doc.Find("a[href]").Each(func(_ int, s *goquery.Selection) {
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
		return nil, fmt.Errorf("could not parse CA APM agents website: no versions found")
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

// In retrieves details for a specific CA APM PHP agent version.
func (w *CaApmAgentWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-%s_linux.tar.gz", ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download CA APM agent: %w", err)
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
