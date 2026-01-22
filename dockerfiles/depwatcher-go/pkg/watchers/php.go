package watchers

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strings"

	"github.com/PuerkitoBio/goquery"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type PHPWatcher struct {
	client base.HTTPClient
}

type phpJSONRelease struct {
	Filename string `json:"filename"`
	SHA256   string `json:"sha256"`
}

type phpVersionData struct {
	Source []phpJSONRelease `json:"source"`
}

func NewPHPWatcher(client base.HTTPClient) *PHPWatcher {
	return &PHPWatcher{client: client}
}

func (w *PHPWatcher) Check(versionFilter string) ([]base.Internal, error) {
	if versionFilter == "" {
		latestVersion, err := w.getLatestSupportedVersion()
		if err != nil {
			return nil, fmt.Errorf("getting latest supported version: %w", err)
		}
		versionFilter = latestVersion
	}

	parts := strings.Split(versionFilter, ".")
	if len(parts) < 2 {
		return nil, fmt.Errorf("version_filter must be in format 'major.minor', got: %s", versionFilter)
	}

	major, minor := parts[0], parts[1]

	versions, err := w.getReleasesFromJSON(major, minor)
	if err == nil && len(versions) > 0 {
		return w.sortAndDedupe(versions), nil
	}

	versions, err = w.getReleasesFromHTML()
	if err != nil {
		return nil, err
	}

	var filtered []base.Internal
	for _, v := range versions {
		vParts := strings.Split(v.Ref, ".")
		if len(vParts) >= 2 && vParts[0] == major && vParts[1] == minor {
			filtered = append(filtered, v)
		}
	}

	return w.sortAndDedupe(filtered), nil
}

func (w *PHPWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("https://php.net/distributions/php-%s.tar.gz", ref)

	parts := strings.Split(ref, ".")
	if len(parts) < 2 {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}
	major, minor := parts[0], parts[1]

	sha256, err := w.getSHA256FromJSON(ref, major, minor)
	if err == nil && sha256 != "" {
		return base.Release{
			Ref:    ref,
			URL:    url,
			SHA256: sha256,
		}, nil
	}

	sha256, err = base.GetSHA256(w.client, url)
	if err != nil {
		return base.Release{}, fmt.Errorf("calculating SHA256: %w", err)
	}

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256,
	}, nil
}

func (w *PHPWatcher) getLatestSupportedVersion() (string, error) {
	versions, err := w.getReleasesFromHTML()
	if err != nil {
		return "", err
	}

	if len(versions) == 0 {
		return "", fmt.Errorf("no PHP versions found")
	}

	sorted := w.sortAndDedupe(versions)
	latest := sorted[len(sorted)-1]
	parts := strings.Split(latest.Ref, ".")
	if len(parts) < 2 {
		return "", fmt.Errorf("invalid version format: %s", latest.Ref)
	}

	return fmt.Sprintf("%s.%s", parts[0], parts[1]), nil
}

func (w *PHPWatcher) getReleasesFromJSON(major, minor string) ([]base.Internal, error) {
	url := fmt.Sprintf("https://www.php.net/releases/index.php?json&version=%s.%s&max=1000", major, minor)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching PHP releases JSON: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var data map[string]phpVersionData
	if err := json.Unmarshal(bodyBytes, &data); err != nil {
		return nil, fmt.Errorf("decoding JSON: %w", err)
	}

	var versions []base.Internal
	for version := range data {
		if !strings.Contains(version, "alpha") && !strings.Contains(version, "beta") && !strings.Contains(version, "RC") {
			versions = append(versions, base.Internal{Ref: version})
		}
	}

	return versions, nil
}

func (w *PHPWatcher) getSHA256FromJSON(ref, major, minor string) (string, error) {
	url := fmt.Sprintf("https://www.php.net/releases/index.php?json&version=%s.%s&max=1000", major, minor)
	resp, err := w.client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var data map[string]phpVersionData
	if err := json.Unmarshal(bodyBytes, &data); err != nil {
		return "", err
	}

	versionData, ok := data[ref]
	if !ok {
		return "", fmt.Errorf("version %s not found", ref)
	}

	filename := fmt.Sprintf("php-%s.tar.gz", ref)
	for _, source := range versionData.Source {
		if source.Filename == filename {
			return source.SHA256, nil
		}
	}

	return "", fmt.Errorf("tar.gz source not found for version %s", ref)
}

func (w *PHPWatcher) getReleasesFromHTML() ([]base.Internal, error) {
	resp, err := w.client.Get("https://secure.php.net/releases/")
	if err != nil {
		return nil, fmt.Errorf("fetching releases page: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	versionRegex := regexp.MustCompile(`^(\d+\.\d+\.\d+)`)
	var versions []base.Internal

	doc.Find("h2").Each(func(i int, s *goquery.Selection) {
		text := strings.TrimSpace(s.Text())
		matches := versionRegex.FindStringSubmatch(text)
		if len(matches) > 1 {
			version := matches[1]
			versions = append(versions, base.Internal{Ref: version})
		}
	})

	return versions, nil
}

func (w *PHPWatcher) sortAndDedupe(versions []base.Internal) []base.Internal {
	seen := make(map[string]bool)
	var unique []base.Internal

	for _, v := range versions {
		if !seen[v.Ref] {
			seen[v.Ref] = true
			unique = append(unique, v)
		}
	}

	sort.Slice(unique, func(i, j int) bool {
		vi, err1 := semver.Parse(unique[i].Ref)
		vj, err2 := semver.Parse(unique[j].Ref)
		if err1 != nil || err2 != nil {
			return unique[i].Ref < unique[j].Ref
		}
		return vi.LessThan(vj)
	})

	return unique
}
