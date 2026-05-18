package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"regexp"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const newrelicIndexURL = "https://download.newrelic.com/newrelic/java-agent/newrelic-agent/"

type NewRelicAgentWatcher struct {
	client base.HTTPClient
}

func NewNewRelicAgentWatcher(client base.HTTPClient) *NewRelicAgentWatcher {
	return &NewRelicAgentWatcher{client: client}
}

func (w *NewRelicAgentWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get(newrelicIndexURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch New Relic agent index: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read New Relic agent index: %w", err)
	}

	// Apache directory listing links look like: <a href="/newrelic/java-agent/newrelic-agent/9.2.0">9.2.0/</a>"
	pattern := regexp.MustCompile(`>(\d+\.\d+\.\d+)/<`)
	var versions []base.Internal

	for _, match := range pattern.FindAllSubmatch(body, -1) {
		versions = append(versions, base.Internal{Ref: string(match[1])})
	}

	if len(versions) == 0 {
		return nil, fmt.Errorf("no New Relic Java agent versions found in index")
	}

	versions = base.SortVersions(versions)

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	return versions, nil
}

func (w *NewRelicAgentWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf("%s%s/newrelic-agent-%s.jar", newrelicIndexURL, ref, ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download New Relic agent: %w", err)
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
