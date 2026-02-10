package watchers

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type GithubReleasesWatcher struct {
	client          base.HTTPClient
	repo            string
	allowPrerelease bool
	extension       string
	fetchSource     bool
}

type githubAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

type githubRelease struct {
	TagName    string        `json:"tag_name"`
	Draft      bool          `json:"draft"`
	Prerelease bool          `json:"prerelease"`
	Assets     []githubAsset `json:"assets"`
}

func (r *githubRelease) Ref() string {
	ref := strings.TrimPrefix(r.TagName, "v")
	// Also strip sapmachine- prefix for SapMachine releases
	ref = strings.TrimPrefix(ref, "sapmachine-")
	return ref
}

func NewGithubReleasesWatcher(client base.HTTPClient, repo string, allowPrerelease bool) *GithubReleasesWatcher {
	return &GithubReleasesWatcher{
		client:          client,
		repo:            repo,
		allowPrerelease: allowPrerelease,
	}
}

func (w *GithubReleasesWatcher) WithExtension(ext string) *GithubReleasesWatcher {
	w.extension = ext
	return w
}

func (w *GithubReleasesWatcher) WithFetchSource(fetch bool) *GithubReleasesWatcher {
	w.fetchSource = fetch
	return w
}

func (w *GithubReleasesWatcher) Check() ([]base.Internal, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return nil, err
	}

	var versions []base.Internal
	alphaNumericRegex := regexp.MustCompile(`[a-zA-Z]+.*$`)

	for _, release := range releases {
		if release.Draft {
			continue
		}
		if release.Prerelease && !w.allowPrerelease {
			continue
		}
		ref := release.Ref()
		if ref == "" {
			continue
		}
		if alphaNumericRegex.MatchString(ref) {
			continue
		}
		versions = append(versions, base.Internal{Ref: ref})
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

func (w *GithubReleasesWatcher) In(ref string) (base.Release, error) {
	release, err := w.findRelease(ref)
	if err != nil {
		return base.Release{}, err
	}

	if w.fetchSource {
		return w.downloadSourceArchive(release)
	}

	return w.downloadAsset(release)
}

func (w *GithubReleasesWatcher) fetchReleases() ([]githubRelease, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/releases", w.repo)
	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching releases: %w", err)
	}
	defer resp.Body.Close()

	var releases []githubRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("decoding releases: %w", err)
	}

	return releases, nil
}

func (w *GithubReleasesWatcher) findRelease(ref string) (*githubRelease, error) {
	releases, err := w.fetchReleases()
	if err != nil {
		return nil, err
	}

	for _, release := range releases {
		if release.Ref() == ref {
			return &release, nil
		}
	}

	return nil, fmt.Errorf("could not find release data for version %s", ref)
}

func (w *GithubReleasesWatcher) downloadAsset(release *githubRelease) (base.Release, error) {
	var matchingAssets []githubAsset
	for _, asset := range release.Assets {
		if strings.HasSuffix(asset.Name, w.extension) {
			matchingAssets = append(matchingAssets, asset)
		}
	}

	if len(matchingAssets) != 1 {
		return base.Release{}, fmt.Errorf("expected 1 asset with extension %s, found %d", w.extension, len(matchingAssets))
	}

	asset := matchingAssets[0]
	sha256, err := w.downloadAndHash(asset.BrowserDownloadURL)
	if err != nil {
		return base.Release{}, err
	}

	return base.Release{
		Ref:    release.Ref(),
		URL:    asset.BrowserDownloadURL,
		SHA256: sha256,
	}, nil
}

func (w *GithubReleasesWatcher) downloadSourceArchive(release *githubRelease) (base.Release, error) {
	url := fmt.Sprintf("https://github.com/%s/archive/%s.tar.gz", w.repo, release.TagName)

	sha256, err := w.downloadAndHash(url)
	if err != nil {
		return base.Release{}, err
	}

	return base.Release{
		Ref:    release.Ref(),
		URL:    url,
		SHA256: sha256,
	}, nil
}

func (w *GithubReleasesWatcher) downloadAndHash(url string) (string, error) {
	headers := http.Header{
		"Accept": []string{"application/octet-stream"},
	}
	resp, err := w.client.GetWithHeaders(url, headers)
	if err != nil {
		return "", fmt.Errorf("downloading file: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	tmpDir := os.TempDir()
	tmpFile := filepath.Join(tmpDir, filepath.Base(url))

	f, err := os.Create(tmpFile)
	if err != nil {
		return "", fmt.Errorf("creating temp file: %w", err)
	}
	defer f.Close()
	defer os.Remove(tmpFile)

	multiWriter := io.MultiWriter(f, hash)
	if _, err := io.Copy(multiWriter, resp.Body); err != nil {
		return "", fmt.Errorf("writing file: %w", err)
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}
