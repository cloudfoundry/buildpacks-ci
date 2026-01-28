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

const minicondaURL = "https://repo.anaconda.com/miniconda/"

type MinicondaWatcher struct {
	client        base.HTTPClient
	pythonVersion string
}

func NewMinicondaWatcher(client base.HTTPClient, pythonVersion string) *MinicondaWatcher {
	return &MinicondaWatcher{
		client:        client,
		pythonVersion: pythonVersion,
	}
}

// Check returns all available Miniconda versions for the specified Python version sorted by semver.
// It parses the HTML directory listing from repo.anaconda.com/miniconda/ and extracts versions
// matching the pattern Miniconda{generation}-py{pythonVersion}_{version}-{build}-Linux-x86_64.sh
func (w *MinicondaWatcher) Check() ([]base.Internal, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return nil, err
	}

	var versions []*semver.Semver
	versionMap := make(map[string]bool)

	for _, rel := range releases {
		version, err := semver.Parse(rel.Version)
		if err != nil {
			continue
		}
		if !versionMap[rel.Version] {
			versionMap[rel.Version] = true
			versions = append(versions, version)
		}
	}

	sort.Slice(versions, func(i, j int) bool {
		return versions[i].LessThan(versions[j])
	})

	var result []base.Internal
	for _, v := range versions {
		result = append(result, base.Internal{Ref: v.String()})
	}

	return result, nil
}

// In returns the release details for a specific Miniconda version.
// It constructs the download URL based on the version and Python version,
// and extracts the SHA256 checksum from the HTML table.
func (w *MinicondaWatcher) In(ref string) (base.Release, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return base.Release{}, err
	}

	for _, rel := range releases {
		if rel.Version == ref {
			return base.Release{
				Ref:    rel.Version,
				URL:    rel.URL,
				SHA256: rel.SHA256,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("version %s not found", ref)
}

type minicondaRelease struct {
	Version string
	Build   string
	URL     string
	SHA256  string
}

func (w *MinicondaWatcher) fetchReleases() ([]minicondaRelease, error) {
	resp, err := w.client.Get(minicondaURL)
	if err != nil {
		return nil, fmt.Errorf("fetching miniconda HTML: %w", err)
	}
	defer resp.Body.Close()

	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("parsing HTML: %w", err)
	}

	generation := strings.Split(w.pythonVersion, ".")[0]
	pythonVersionNoDots := strings.ReplaceAll(w.pythonVersion, ".", "")

	// Pattern: Miniconda3-py39_23.1.0-1-Linux-x86_64.sh
	pattern := fmt.Sprintf(`Miniconda%s-py%s_([\d\.]+)-([\d]+)-Linux-x86_64\.sh`, generation, pythonVersionNoDots)
	re := regexp.MustCompile(pattern)

	var releases []minicondaRelease

	doc.Find("tr").Each(func(i int, row *goquery.Selection) {
		link := row.Find("td:first-child a")
		href, exists := link.Attr("href")
		if !exists {
			return
		}

		matches := re.FindStringSubmatch(href)
		if len(matches) != 3 {
			return
		}

		version := matches[1]
		build := matches[2]

		sha256 := strings.TrimSpace(row.Find("td:nth-child(4)").Text())

		url := fmt.Sprintf("%sMiniconda%s-py%s_%s-%s-Linux-x86_64.sh",
			minicondaURL, generation, pythonVersionNoDots, version, build)

		releases = append(releases, minicondaRelease{
			Version: version,
			Build:   build,
			URL:     url,
			SHA256:  sha256,
		})
	})

	if len(releases) == 0 {
		return nil, fmt.Errorf("no releases found for Python version %s", w.pythonVersion)
	}

	return releases, nil
}
