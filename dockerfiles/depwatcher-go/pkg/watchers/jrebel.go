package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const jrebelReleasesURL = "https://www.jrebel.com/jrebel-releases"
const jrebelDownloadBase = "https://dl.zeroturnaround.com/jrebel/releases/jrebel-%s-nosetup.zip"

var jrebelVersionPattern = regexp.MustCompile(`href="https://dl\.zeroturnaround\.com/jrebel/releases/jrebel-(\d{4}\.\d+\.\d+)-nosetup\.zip"`)

type JRebelWatcher struct {
	client base.HTTPClient
}

func NewJRebelWatcher(client base.HTTPClient) *JRebelWatcher {
	return &JRebelWatcher{client: client}
}

func (w *JRebelWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get(jrebelReleasesURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch JRebel releases page: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read JRebel releases page: %w", err)
	}

	seen := make(map[string]bool)
	var versions []base.Internal

	for _, match := range jrebelVersionPattern.FindAllSubmatch(body, -1) {
		v := string(match[1])
		if !seen[v] {
			seen[v] = true
			versions = append(versions, base.Internal{Ref: v})
		}
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no JRebel versions found on releases page")
	}

	versions = base.SortVersions(versions)

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

func (w *JRebelWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf(jrebelDownloadBase, ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download JRebel: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, resp.Body); err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: fmt.Sprintf("%x", hash.Sum(nil)),
	}, nil
}
