package watchers

import (
	"fmt"
	"io"
	"sort"
	"strings"
	"time"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type HttpdWatcher struct {
	client     base.HTTPClient
	retryDelay time.Duration
	maxRetries int
}

func NewHttpdWatcher(client base.HTTPClient) *HttpdWatcher {
	return &HttpdWatcher{
		client:     client,
		retryDelay: 5 * time.Second,
		maxRetries: 3,
	}
}

func NewHttpdWatcherWithRetry(client base.HTTPClient, retryDelay time.Duration, maxRetries int) *HttpdWatcher {
	return &HttpdWatcher{
		client:     client,
		retryDelay: retryDelay,
		maxRetries: maxRetries,
	}
}

// Check fetches all available Apache httpd versions from GitHub tags
func (w *HttpdWatcher) Check() ([]base.Internal, error) {
	tagsWatcher := NewGithubTagsWatcher(w.client, "apache/httpd")
	tags, err := tagsWatcher.Check(`^\d+\.\d+\.\d+$`)
	if err != nil {
		return nil, fmt.Errorf("fetching httpd tags: %w", err)
	}

	sort.Slice(tags, func(i, j int) bool {
		vi, err1 := semver.Parse(tags[i].Ref)
		vj, err2 := semver.Parse(tags[j].Ref)
		if err1 != nil || err2 != nil {
			return tags[i].Ref < tags[j].Ref
		}
		return vi.LessThan(vj)
	})

	return tags, nil
}

// In fetches detailed information about a specific Apache httpd version
func (w *HttpdWatcher) In(ref string) (base.Release, error) {
	shaURL := fmt.Sprintf("https://archive.apache.org/dist/httpd/httpd-%s.tar.bz2.sha256", ref)

	var sha256 string
	var lastErr error

	for attempt := 0; attempt < w.maxRetries; attempt++ {
		resp, err := w.client.Get(shaURL)
		if err != nil {
			lastErr = err
			time.Sleep(w.retryDelay)
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode == 200 {
			bodyBytes, err := io.ReadAll(resp.Body)
			if err != nil {
				lastErr = err
				time.Sleep(w.retryDelay)
				continue
			}

			parts := strings.Fields(string(bodyBytes))
			if len(parts) > 0 {
				sha256 = parts[0]
				break
			}
		}

		lastErr = fmt.Errorf("received status code %d", resp.StatusCode)
		time.Sleep(w.retryDelay)
	}

	if sha256 == "" {
		if lastErr != nil {
			return base.Release{}, fmt.Errorf("failed to fetch SHA256 after %d attempts: %w", w.maxRetries, lastErr)
		}
		return base.Release{}, fmt.Errorf("failed to fetch SHA256 after %d attempts", w.maxRetries)
	}

	downloadURL := fmt.Sprintf("https://dlcdn.apache.org/httpd/httpd-%s.tar.bz2", ref)

	return base.Release{
		Ref:    ref,
		URL:    downloadURL,
		SHA256: sha256,
	}, nil
}
