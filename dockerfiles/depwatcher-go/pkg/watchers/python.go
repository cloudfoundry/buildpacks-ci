package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type PythonWatcher struct {
	client base.HTTPClient
}

type pythonAPIRelease struct {
	Name        string `json:"name"`
	IsPublished bool   `json:"is_published"`
	PreRelease  bool   `json:"pre_release"`
}

func NewPythonWatcher(client base.HTTPClient) *PythonWatcher {
	return &PythonWatcher{client: client}
}

// extractMajorVersion returns the major version from a version filter like "3.10.x" -> "3"
func extractMajorVersion(versionFilter string) string {
	if versionFilter == "" {
		return ""
	}
	parts := strings.Split(versionFilter, ".")
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}

func (w *PythonWatcher) Check(versionFilter string) ([]base.Internal, error) {
	// Build API URL with server-side filtering
	apiURL := "https://www.python.org/api/v2/downloads/release/?pre_release=false"
	if major := extractMajorVersion(versionFilter); major != "" {
		apiURL += "&version=" + major
	}

	resp, err := w.client.Get(apiURL)
	if err != nil {
		return nil, fmt.Errorf("fetching python API: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response body: %w", err)
	}

	var releases []pythonAPIRelease
	if err := json.Unmarshal(body, &releases); err != nil {
		return nil, fmt.Errorf("parsing JSON: %w", err)
	}

	var versions []base.Internal
	versionRegex := regexp.MustCompile(`Python\s+(\d+\.\d+\.\d+)`)

	for _, release := range releases {
		matches := versionRegex.FindStringSubmatch(release.Name)
		if len(matches) > 1 {
			versions = append(versions, base.Internal{Ref: matches[1]})
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no versions found in API response")
	}

	return base.SortVersions(versions), nil
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

	doc.Find("a").Each(func(i int, s *goquery.Selection) {
		if strings.Contains(s.Text(), "Gzipped source tarball") {
			href, exists := s.Attr("href")
			if exists {
				downloadURL = href
			}
		}
	})

	if downloadURL == "" {
		return base.Release{}, fmt.Errorf("could not find download URL for Python %s", ref)
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
