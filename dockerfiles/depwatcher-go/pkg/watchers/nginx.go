package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type NginxWatcher struct {
	client base.HTTPClient
}

func NewNginxWatcher(client base.HTTPClient) *NginxWatcher {
	return &NginxWatcher{client: client}
}

// Check fetches all available Nginx versions from GitHub tags
func (w *NginxWatcher) Check() ([]base.Internal, error) {
	tagsWatcher := NewGithubTagsWatcher(w.client, "nginx/nginx")
	tags, err := tagsWatcher.Check(`^release-\d+\.\d+\.\d+$`)
	if err != nil {
		return nil, fmt.Errorf("fetching nginx tags: %w", err)
	}

	versionRe := regexp.MustCompile(`^release-(.+)$`)
	var versions []base.Internal

	for _, tag := range tags {
		matches := versionRe.FindStringSubmatch(tag.Ref)
		if len(matches) > 1 {
			versions = append(versions, base.Internal{Ref: matches[1]})
		}
	}

	return base.SortVersions(versions), nil
}

// In fetches detailed information about a specific Nginx version
func (w *NginxWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("http://nginx.org/download/nginx-%s.tar.gz", ref)
	pgpURL := fmt.Sprintf("http://nginx.org/download/nginx-%s.tar.gz.asc", ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("fetching nginx tarball: %w", err)
	}
	defer resp.Body.Close()

	hash := sha256.New()
	_, err = io.Copy(hash, resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("computing SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256sum,
		PGP:    pgpURL,
	}, nil
}
