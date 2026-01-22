package watchers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const (
	appdynamicsLatestURI = "https://download.appdynamics.com/download/downloadfilelatest/"
	appdynamicsFetchURI  = "https://download.appdynamics.com/download/downloadfile/"
	appdynamicsTokenURI  = "https://identity.msrv.saas.appdynamics.com/v2.0/oauth/token"
)

type AppDynamicsWatcher struct {
	client    base.HTTPClient
	agentType string
	username  string
	password  string
}

type appdynamicsAPIResponse struct {
	DownloadPath string `json:"download_path"`
	FileType     string `json:"filetype"`
	Version      string `json:"version"`
	Checksum     string `json:"sha256_checksum"`
}

type appdynamicsAPIPageResponse struct {
	Count    int                      `json:"count"`
	Next     string                   `json:"next"`
	Previous string                   `json:"previous"`
	Results  []appdynamicsAPIResponse `json:"results"`
}

type appdynamicsTokenResponse struct {
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	AccessToken string `json:"access_token"`
	Scope       string `json:"scope"`
}

var appdynamicsVersionPattern = regexp.MustCompile(`(\d+)\.(\d+)\.(\d+)\.(\d+)`)

// NewAppDynamicsWatcher creates a new AppDynamics watcher for generic agents (java, machine, php, php-tar).
// This is distinct from AppdAgentWatcher which only handles PHP agents from Pivotal's download server.
func NewAppDynamicsWatcher(client base.HTTPClient, agentType, username, password string) *AppDynamicsWatcher {
	return &AppDynamicsWatcher{
		client:    client,
		agentType: agentType,
		username:  username,
		password:  password,
	}
}

// Check retrieves the latest version of the AppDynamics agent.
// Returns a single version (the latest) converted from X.Y.Z.W to X.Y.Z-W format.
func (w *AppDynamicsWatcher) Check() ([]base.Internal, error) {
	resp, err := w.client.Get(appdynamicsLatestURI)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch AppDynamics latest version: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code %d from %s", resp.StatusCode, appdynamicsLatestURI)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	var apiResponses []appdynamicsAPIResponse
	if err := json.Unmarshal(body, &apiResponses); err != nil {
		return nil, fmt.Errorf("failed to parse API response: %w", err)
	}

	// Find the response matching our agent type
	for _, apiResp := range apiResponses {
		if apiResp.FileType == w.agentType {
			version := w.convertVersion(apiResp.Version)
			if version == "" {
				return nil, fmt.Errorf("failed to parse version %s", apiResp.Version)
			}
			return []base.Internal{{Ref: version}}, nil
		}
	}

	return nil, fmt.Errorf("no version found for agent type %s", w.agentType)
}

// In retrieves release details for a specific AppDynamics agent version.
// The version should be in X.Y.Z-W format (will be converted to X.Y.Z.W for API queries).
func (w *AppDynamicsWatcher) In(ref string) (base.Release, error) {
	// Convert version from X.Y.Z-W back to X.Y.Z.W for API query
	apiVersion := strings.Replace(ref, "-", ".", 1)

	// Parse version parts
	parts := strings.Split(apiVersion, ".")
	if len(parts) != 4 {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}

	// Build query parameters
	var queryURL string
	if w.agentType == "php-tar" {
		queryURL = fmt.Sprintf("%s?apm_os=linux&version=%s&apm=php&filetype=tar", appdynamicsFetchURI, apiVersion)
	} else {
		queryURL = fmt.Sprintf("%s?apm_os=linux&version=%s&apm=%s", appdynamicsFetchURI, apiVersion, w.agentType)
	}

	resp, err := w.client.Get(queryURL)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to fetch version details: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return base.Release{}, fmt.Errorf("unexpected status code %d from %s", resp.StatusCode, appdynamicsFetchURI)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to read response body: %w", err)
	}

	var pageResp appdynamicsAPIPageResponse
	if err := json.Unmarshal(body, &pageResp); err != nil {
		return base.Release{}, fmt.Errorf("failed to parse API response: %w", err)
	}

	// Find the matching agent type in results
	for _, result := range pageResp.Results {
		if result.FileType == w.agentType {
			return base.Release{
				Ref:    ref,
				URL:    result.DownloadPath,
				SHA256: result.Checksum,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("version %s not found for agent type %s", ref, w.agentType)
}

// fetchAPIToken retrieves an OAuth token from AppDynamics identity service.
// This token is required for downloading agents.
func (w *AppDynamicsWatcher) fetchAPIToken() (string, error) {
	payload := map[string]interface{}{
		"username": w.username,
		"password": w.password,
		"scopes":   []string{"download"},
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal token request: %w", err)
	}

	resp, err := http.Post(appdynamicsTokenURI, "application/json", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return "", fmt.Errorf("failed to request token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status code %d from token endpoint", resp.StatusCode)
	}

	var tokenResp appdynamicsTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to parse token response: %w", err)
	}

	return fmt.Sprintf("%s %s", tokenResp.TokenType, tokenResp.AccessToken), nil
}

// convertVersion converts AppDynamics version format from X.Y.Z.W to X.Y.Z-W
func (w *AppDynamicsWatcher) convertVersion(version string) string {
	matches := appdynamicsVersionPattern.FindStringSubmatch(version)
	if len(matches) != 5 {
		return ""
	}
	return fmt.Sprintf("%s.%s.%s-%s", matches[1], matches[2], matches[3], matches[4])
}

// sortAppDynamicsVersions sorts versions in ascending order using semver-like comparison
func sortAppDynamicsVersions(versions []base.Internal) {
	sort.Slice(versions, func(i, j int) bool {
		vi := parseAppDynamicsVersion(versions[i].Ref)
		vj := parseAppDynamicsVersion(versions[j].Ref)
		return vi.lessThan(vj)
	})
}

type appdynamicsVersion struct {
	major int
	minor int
	patch int
	build int
}

func parseAppDynamicsVersion(version string) appdynamicsVersion {
	var v appdynamicsVersion

	// Handle X.Y.Z-W format
	parts := strings.Split(version, ".")
	if len(parts) < 3 {
		return v
	}

	fmt.Sscanf(parts[0], "%d", &v.major)
	fmt.Sscanf(parts[1], "%d", &v.minor)

	// Handle patch-build (e.g., "0-1234")
	patchParts := strings.Split(parts[2], "-")
	if len(patchParts) >= 1 {
		fmt.Sscanf(patchParts[0], "%d", &v.patch)
	}
	if len(patchParts) >= 2 {
		fmt.Sscanf(patchParts[1], "%d", &v.build)
	}

	return v
}

func (v appdynamicsVersion) lessThan(other appdynamicsVersion) bool {
	if v.major != other.major {
		return v.major < other.major
	}
	if v.minor != other.minor {
		return v.minor < other.minor
	}
	if v.patch != other.patch {
		return v.patch < other.patch
	}
	return v.build < other.build
}
