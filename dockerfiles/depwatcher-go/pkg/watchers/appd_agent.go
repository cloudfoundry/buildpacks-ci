package watchers

import (
	"crypto/sha256"
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"gopkg.in/yaml.v3"
)

type AppdAgentWatcher struct {
	client base.HTTPClient
}

func NewAppdAgentWatcher(client base.HTTPClient) *AppdAgentWatcher {
	return &AppdAgentWatcher{client: client}
}

// Check retrieves AppDynamics PHP agent versions from Pivotal download server.
// Returns the last 10 versions sorted by calendar versioning (YY.M.P-X format).
// Parses index.yml where keys use underscore (1.1.1_2) but converts to hyphen (1.1.1-2).
func (w *AppdAgentWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get("https://download.run.pivotal.io/appdynamics-php/index.yml")
	if err != nil {
		return nil, fmt.Errorf("failed to fetch AppDynamics agent index: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read index: %w", err)
	}

	var index map[string]string
	if err := yaml.Unmarshal(body, &index); err != nil {
		return nil, fmt.Errorf("failed to parse index YAML: %w", err)
	}

	if len(index) == 0 {
		return nil, fmt.Errorf("no versions found in index")
	}

	var versions []string
	for key := range index {
		version := strings.Replace(key, "_", "-", 1)
		versions = append(versions, version)
	}

	sort.Slice(versions, func(i, j int) bool {
		vi := parseCalendarVersion(versions[i])
		vj := parseCalendarVersion(versions[j])
		return vi.lessThan(vj)
	})

	if len(versions) > 10 {
		versions = versions[len(versions)-10:]
	}

	result := make([]base.Internal, len(versions))
	for i, version := range versions {
		result[i] = base.Internal{Ref: version}
	}

	return result, nil
}

// In retrieves details for a specific AppDynamics PHP agent version.
// Downloads the tarball to compute its SHA256 checksum.
func (w *AppdAgentWatcher) In(ref string) (base.Release, error) {
	resp, err := w.client.Get("https://download.run.pivotal.io/appdynamics-php/index.yml")
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to fetch AppDynamics agent index: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to read index: %w", err)
	}

	var index map[string]string
	if err := yaml.Unmarshal(body, &index); err != nil {
		return base.Release{}, fmt.Errorf("failed to parse index YAML: %w", err)
	}

	key := strings.Replace(ref, "-", "_", 1)
	url, exists := index[key]
	if !exists {
		return base.Release{}, fmt.Errorf("version %s not found in index", ref)
	}

	downloadResp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download AppDynamics agent: %w", err)
	}
	defer downloadResp.Body.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, downloadResp.Body); err != nil {
		return base.Release{}, fmt.Errorf("failed to compute SHA256: %w", err)
	}

	sha256sum := fmt.Sprintf("%x", hash.Sum(nil))

	return base.Release{
		Ref:    ref,
		URL:    url,
		SHA256: sha256sum,
	}, nil
}

// calendarVersion represents AppDynamics calendar versioning (YY.M.P-X)
type calendarVersion struct {
	major    int // Year (YY)
	minor    int // Month (M)
	patch    int // Patch (P)
	metadata int // Build metadata (X)
}

// parseCalendarVersion parses calendar version format (e.g., "22.1.0-14")
func parseCalendarVersion(version string) calendarVersion {
	var cv calendarVersion

	parts := strings.Split(version, ".")
	if len(parts) < 3 {
		return cv
	}

	fmt.Sscanf(parts[0], "%d", &cv.major)
	fmt.Sscanf(parts[1], "%d", &cv.minor)

	patchParts := strings.Split(parts[2], "-")
	if len(patchParts) >= 1 {
		fmt.Sscanf(patchParts[0], "%d", &cv.patch)
	}
	if len(patchParts) >= 2 {
		fmt.Sscanf(patchParts[1], "%d", &cv.metadata)
	}

	return cv
}

func (cv calendarVersion) lessThan(other calendarVersion) bool {
	if cv.major != other.major {
		return cv.major < other.major
	}
	if cv.minor != other.minor {
		return cv.minor < other.minor
	}
	if cv.patch != other.patch {
		return cv.patch < other.patch
	}
	return cv.metadata < other.metadata
}
