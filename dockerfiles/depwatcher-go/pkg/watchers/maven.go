package watchers

import (
	"encoding/base64"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type MavenWatcher struct {
	client     base.HTTPClient
	uri        string
	groupId    string
	artifactId string
	classifier string
	packaging  string
	username   string
	password   string
}

type mavenMetadata struct {
	Versioning struct {
		Versions []string `xml:"versions>version"`
	} `xml:"versioning"`
}

var mavenVersionPattern = regexp.MustCompile(`^([\d]+)\.([\d]+)\.([\d]+)[.-]?(.*)`)

func NewMavenWatcher(client base.HTTPClient, uri, groupId, artifactId, classifier, packaging, username, password string) *MavenWatcher {
	if packaging == "" {
		packaging = "jar"
	}
	return &MavenWatcher{
		client:     client,
		uri:        uri,
		groupId:    groupId,
		artifactId: artifactId,
		classifier: classifier,
		packaging:  packaging,
		username:   username,
		password:   password,
	}
}

func (w *MavenWatcher) Check() ([]base.Internal, error) {
	if w.uri == "" {
		return nil, fmt.Errorf("uri must be specified")
	}
	if w.groupId == "" {
		return nil, fmt.Errorf("group_id must be specified")
	}
	if w.artifactId == "" {
		return nil, fmt.Errorf("artifact_id must be specified")
	}

	metadataURL := w.buildMetadataURL()

	headers := http.Header{}
	if w.username != "" && w.password != "" {
		auth := w.username + ":" + w.password
		headers.Set("Authorization", "Basic "+base64Encode(auth))
	}

	resp, err := w.client.GetWithHeaders(metadataURL, headers)
	if err != nil {
		return nil, fmt.Errorf("fetching Maven metadata: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code %d fetching %s", resp.StatusCode, metadataURL)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var metadata mavenMetadata
	if err := xml.Unmarshal(bodyBytes, &metadata); err != nil {
		return nil, fmt.Errorf("parsing XML metadata: %w", err)
	}

	var internals []base.Internal
	for _, version := range metadata.Versioning.Versions {
		normalizedVersion := w.normalizeVersion(version)
		if normalizedVersion != "" {
			internals = append(internals, base.Internal{Ref: normalizedVersion})
		}
	}

	return base.SortVersions(internals), nil
}

func base64Encode(s string) string {
	return base64.StdEncoding.EncodeToString([]byte(s))
}

func (w *MavenWatcher) In(ref string) (base.Release, error) {
	if w.uri == "" {
		return base.Release{}, fmt.Errorf("uri must be specified")
	}
	if w.groupId == "" {
		return base.Release{}, fmt.Errorf("group_id must be specified")
	}
	if w.artifactId == "" {
		return base.Release{}, fmt.Errorf("artifact_id must be specified")
	}

	artifactURL := w.buildArtifactURL(ref)

	return base.Release{
		Ref: ref,
		URL: artifactURL,
	}, nil
}

func (w *MavenWatcher) buildMetadataURL() string {
	groupPath := strings.ReplaceAll(w.groupId, ".", "/")
	return fmt.Sprintf("%s/%s/%s/maven-metadata.xml", w.uri, groupPath, w.artifactId)
}

func (w *MavenWatcher) buildArtifactURL(version string) string {
	groupPath := strings.ReplaceAll(w.groupId, ".", "/")
	filename := w.buildArtifactFilename(version)
	return fmt.Sprintf("%s/%s/%s/%s/%s", w.uri, groupPath, w.artifactId, version, filename)
}

func (w *MavenWatcher) buildArtifactFilename(version string) string {
	name := fmt.Sprintf("%s-%s", w.artifactId, version)
	if w.classifier != "" {
		name = fmt.Sprintf("%s-%s", name, w.classifier)
	}
	return fmt.Sprintf("%s.%s", name, w.packaging)
}

func (w *MavenWatcher) normalizeVersion(version string) string {
	matches := mavenVersionPattern.FindStringSubmatch(version)
	if matches == nil {
		return ""
	}

	normalized := fmt.Sprintf("%s.%s.%s", matches[1], matches[2], matches[3])
	if matches[4] != "" {
		normalized = fmt.Sprintf("%s-%s", normalized, matches[4])
	}

	return normalized
}
