package watchers

import (
	"fmt"
	"io"
	"regexp"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type TomcatWatcher struct {
	client base.HTTPClient
	uri    string
}

var tomcatVersionPattern = regexp.MustCompile(`href="v([\d]+)\.([\d]+)\.([\d]+)/"`)

func NewTomcatWatcher(client base.HTTPClient, uri string) *TomcatWatcher {
	return &TomcatWatcher{
		client: client,
		uri:    uri,
	}
}

func (w *TomcatWatcher) Check() ([]base.Internal, error) {
	if w.uri == "" {
		return nil, fmt.Errorf("uri must be specified")
	}

	resp, err := w.client.Get(w.uri)
	if err != nil {
		return nil, fmt.Errorf("fetching Tomcat directory listing: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code %d fetching %s", resp.StatusCode, w.uri)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	body := string(bodyBytes)

	var internals []base.Internal
	matches := tomcatVersionPattern.FindAllStringSubmatch(body, -1)
	for _, match := range matches {
		if len(match) >= 4 {
			ref := fmt.Sprintf("%s.%s.%s", match[1], match[2], match[3])
			internals = append(internals, base.Internal{Ref: ref})
		}
	}

	return base.SortVersions(internals), nil
}

func (w *TomcatWatcher) In(ref string) (base.Release, error) {
	if w.uri == "" {
		return base.Release{}, fmt.Errorf("uri must be specified")
	}

	filename := fmt.Sprintf("apache-tomcat-%s.tar.gz", ref)
	url := fmt.Sprintf("%s/v%s/bin/%s", strings.TrimRight(w.uri, "/"), ref, filename)

	return base.Release{
		Ref: ref,
		URL: url,
	}, nil
}
