package watchers

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const (
	appdynamicsLatestURI = "https://download.appdynamics.com/download/downloadfilelatest/"
	appdynamicsFetchURI  = "https://download.appdynamics.com/download/downloadfile/"
	appdynamicsOAuthURI  = "https://identity.msrv.saas.appdynamics.com/v2.0/oauth/token"
)

type AppDynamicsWatcher struct {
	client    base.HTTPClient
	agentType string
	username  string
	password  string
}

type appdynamicsOAuthRequest struct {
	Username string   `json:"username"`
	Password string   `json:"password"`
	Scopes   []string `json:"scopes"`
}

type appdynamicsOAuthResponse struct {
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	AccessToken string `json:"access_token"`
	Scope       string `json:"scope"`
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

var appdynamicsVersionPattern = regexp.MustCompile(`(\d+)\.(\d+)\.(\d+)\.(\d+)`)

// mapAgentTypeToFileType maps the agent_type configuration value to the actual filetype used by the AppDynamics API.
// This provides backward compatibility as the API has changed from "java" to "java-jdk8".
func mapAgentTypeToFileType(agentType string) string {
	switch agentType {
	case "java":
		return "java-jdk8"
	default:
		return agentType
	}
}

// NewAppDynamicsWatcher creates a new AppDynamics watcher for generic agents (java, machine, php, php-tar).
// This is distinct from AppdAgentWatcher which only handles PHP agents from Pivotal's download server.
// Note: agent_type "java" is automatically mapped to "java-jdk8" for API compatibility.
// For Java agents, OAuth credentials can be provided via username/password parameters or environment variables.
func NewAppDynamicsWatcher(client base.HTTPClient, agentType, username, password string) *AppDynamicsWatcher {
	// Fall back to environment variables if credentials not provided
	if username == "" {
		username = os.Getenv("APPDYNAMICS_USERNAME")
	}
	if password == "" {
		password = os.Getenv("APPDYNAMICS_PASSWORD")
	}

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

	// Map agent type to the actual filetype used by the API
	fileType := mapAgentTypeToFileType(w.agentType)

	// Find the response matching our agent type
	for _, apiResp := range apiResponses {
		if apiResp.FileType == fileType {
			version := w.convertVersion(apiResp.Version)
			if version == "" {
				return nil, fmt.Errorf("failed to parse version %s", apiResp.Version)
			}
			return []base.Internal{{Ref: version}}, nil
		}
	}

	return nil, fmt.Errorf("no version found for agent type %s (filetype: %s)", w.agentType, fileType)
}

// fetchOAuthToken retrieves an OAuth token from AppDynamics for authenticated downloads.
func (w *AppDynamicsWatcher) fetchOAuthToken() (string, error) {
	if w.username == "" || w.password == "" {
		return "", fmt.Errorf("APPDYNAMICS_USERNAME and APPDYNAMICS_PASSWORD environment variables must be set")
	}

	reqBody := appdynamicsOAuthRequest{
		Username: w.username,
		Password: w.password,
		Scopes:   []string{"download"},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal OAuth request: %w", err)
	}

	req, err := http.NewRequest("POST", appdynamicsOAuthURI, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create OAuth request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to fetch OAuth token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OAuth request failed with status %d: %s", resp.StatusCode, string(body))
	}

	var oauthResp appdynamicsOAuthResponse
	if err := json.NewDecoder(resp.Body).Decode(&oauthResp); err != nil {
		return "", fmt.Errorf("failed to parse OAuth response: %w", err)
	}

	return fmt.Sprintf("%s %s", oauthResp.TokenType, oauthResp.AccessToken), nil
}

// downloadWithAuth downloads a file from AppDynamics with OAuth authentication and returns its content.
func (w *AppDynamicsWatcher) downloadWithAuth(url string) ([]byte, error) {
	token, err := w.fetchOAuthToken()
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create download request: %w", err)
	}
	req.Header.Set("Authorization", token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to download file: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("download failed with status %d: %s", resp.StatusCode, string(body))
	}

	return io.ReadAll(resp.Body)
}

// In retrieves release details for a specific AppDynamics agent version.
// The version should be in X.Y.Z-W format (will be converted to X.Y.Z.W for API queries).
// For Java agents, this downloads the actual file with OAuth to compute the correct SHA256.
func (w *AppDynamicsWatcher) In(ref string) (base.Release, error) {
	// Convert version from X.Y.Z-W back to X.Y.Z.W for API query
	apiVersion := strings.Replace(ref, "-", ".", 1)

	// Parse version parts
	parts := strings.Split(apiVersion, ".")
	if len(parts) != 4 {
		return base.Release{}, fmt.Errorf("invalid version format: %s", ref)
	}

	// Build query parameters
	// Map agent type to the actual filetype used by the API
	fileType := mapAgentTypeToFileType(w.agentType)

	var queryURL string
	if w.agentType == "php-tar" {
		queryURL = fmt.Sprintf("%s?apm_os=linux&version=%s&apm=php&filetype=tar", appdynamicsFetchURI, apiVersion)
	} else {
		// Use the mapped filetype as the apm parameter
		queryURL = fmt.Sprintf("%s?apm=%s&version=%s", appdynamicsFetchURI, fileType, apiVersion)
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
		if result.FileType == fileType {
			// For Java agents, download the file with OAuth and compute SHA256
			// because the API's SHA256 is incorrect (returns HTML login page hash)
			if w.agentType == "java" && w.username != "" && w.password != "" {
				content, err := w.downloadWithAuth(result.DownloadPath)
				if err != nil {
					return base.Release{}, fmt.Errorf("failed to download Java agent: %w", err)
				}

				// Compute SHA256 from downloaded content
				hash := sha256.Sum256(content)
				computedSHA256 := fmt.Sprintf("%x", hash)

				return base.Release{
					Ref:    ref,
					URL:    result.DownloadPath,
					SHA256: computedSHA256,
				}, nil
			}

			// For other agents (php-tar, machine), or Java without credentials, use API-provided SHA256
			// Note: For Java agents without credentials, the SHA256 will be incorrect
			return base.Release{
				Ref:    ref,
				URL:    result.DownloadPath,
				SHA256: result.Checksum,
			}, nil
		}
	}

	return base.Release{}, fmt.Errorf("version %s not found for agent type %s (filetype: %s)", ref, w.agentType, fileType)
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
