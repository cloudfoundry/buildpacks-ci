package watchers

import (
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

type DotnetReleasesIndex struct {
	ReleasesIndex []DotnetReleaseChannel `json:"releases-index"`
}

type DotnetReleaseChannel struct {
	ChannelVersion string `json:"channel-version"`
	SupportPhase   string `json:"support-phase"`
}

type DotnetReleasesJSON struct {
	Releases []DotnetRelease `json:"releases"`
}

type DotnetRelease struct {
	SDK               *DotnetSDK        `json:"sdk,omitempty"`
	Runtime           *DotnetRuntime    `json:"runtime,omitempty"`
	AspnetcoreRuntime *DotnetAspnetcore `json:"aspnetcore-runtime,omitempty"`
}

type DotnetSDK struct {
	Version string       `json:"version"`
	Files   []DotnetFile `json:"files"`
}

type DotnetRuntime struct {
	Version string       `json:"version"`
	Files   []DotnetFile `json:"files"`
}

type DotnetAspnetcore struct {
	Version string       `json:"version"`
	Files   []DotnetFile `json:"files"`
}

type DotnetFile struct {
	Name string `json:"name"`
	URL  string `json:"url"`
	Hash string `json:"hash"`
}

type DotnetReleaseInfo struct {
	Ref            string
	URL            string
	SHA512         string
	RuntimeVersion string
}

type DotnetWatcher struct {
	client     base.HTTPClient
	targetType string
}

func NewDotnetSDKWatcher(client base.HTTPClient) *DotnetWatcher {
	return &DotnetWatcher{
		client:     client,
		targetType: "sdk",
	}
}

func NewDotnetRuntimeWatcher(client base.HTTPClient) *DotnetWatcher {
	return &DotnetWatcher{
		client:     client,
		targetType: "runtime",
	}
}

func NewDotnetAspnetcoreWatcher(client base.HTTPClient) *DotnetWatcher {
	return &DotnetWatcher{
		client:     client,
		targetType: "aspnetcore",
	}
}

func (w *DotnetWatcher) Check(versionFilter string) ([]base.Internal, error) {
	version := versionFilter
	if version == "" || version == "latest" {
		latestVersion, err := w.getLatestVersion()
		if err != nil {
			return nil, fmt.Errorf("getting latest version: %w", err)
		}
		version = latestVersion
	}

	channelVersion := w.getChannelVersion(version)
	releases, err := w.getReleases(channelVersion)
	if err != nil {
		return nil, err
	}

	versions := w.getVersions(releases, version)

	var result []base.Internal
	for _, v := range versions {
		sv, err := semver.Parse(v)
		if err != nil {
			continue
		}
		if sv.IsFinalRelease() {
			result = append(result, base.Internal{Ref: v})
		}
	}

	return w.reverseVersions(w.uniqueVersions(result)), nil
}

func (w *DotnetWatcher) In(ref string) (*DotnetReleaseInfo, error) {
	channelVersion := w.getChannelVersion(ref)
	releases, err := w.getReleases(channelVersion)
	if err != nil {
		return nil, err
	}

	file, runtimeVersion, err := w.getFile(releases, ref)
	if err != nil {
		return nil, err
	}

	return &DotnetReleaseInfo{
		Ref:            ref,
		URL:            file.URL,
		SHA512:         strings.ToLower(file.Hash),
		RuntimeVersion: runtimeVersion,
	}, nil
}

func (w *DotnetWatcher) DownloadToDir(ref, outputDir string) error {
	releaseInfo, err := w.In(ref)
	if err != nil {
		return err
	}

	if err := w.downloadFile(releaseInfo.URL, outputDir, releaseInfo.SHA512); err != nil {
		return err
	}

	runtimeVersionFile := filepath.Join(outputDir, "runtime_version")
	if err := os.WriteFile(runtimeVersionFile, []byte(releaseInfo.RuntimeVersion), 0644); err != nil {
		return fmt.Errorf("writing runtime_version file: %w", err)
	}

	return nil
}

func (w *DotnetWatcher) getLatestVersion() (string, error) {
	url := "https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/releases-index.json"

	resp, err := w.client.Get(url)
	if err != nil {
		return "", fmt.Errorf("fetching releases index: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("reading response: %w", err)
	}

	var index DotnetReleasesIndex
	if err := json.Unmarshal(body, &index); err != nil {
		return "", fmt.Errorf("parsing releases index: %w", err)
	}

	for _, release := range index.ReleasesIndex {
		if release.SupportPhase != "preview" && release.SupportPhase != "go-live" {
			return release.ChannelVersion, nil
		}
	}

	return "", fmt.Errorf("no stable release found")
}

func (w *DotnetWatcher) getReleases(channelVersion string) ([]DotnetRelease, error) {
	url := fmt.Sprintf("https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/%s/releases.json", channelVersion)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching releases: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var releasesJSON DotnetReleasesJSON
	if err := json.Unmarshal(body, &releasesJSON); err != nil {
		return nil, fmt.Errorf("parsing releases: %w", err)
	}

	return releasesJSON.Releases, nil
}

func (w *DotnetWatcher) getVersions(releases []DotnetRelease, versionFilter string) []string {
	versionPrefix := strings.TrimSuffix(versionFilter, "X")
	var versions []string

	switch w.targetType {
	case "sdk":
		for _, r := range releases {
			if r.SDK != nil && strings.HasPrefix(r.SDK.Version, versionPrefix) {
				versions = append(versions, r.SDK.Version)
			}
		}
	case "runtime":
		for _, r := range releases {
			if r.Runtime != nil {
				versions = append(versions, r.Runtime.Version)
			}
		}
	case "aspnetcore":
		for _, r := range releases {
			if r.AspnetcoreRuntime != nil {
				versions = append(versions, r.AspnetcoreRuntime.Version)
			}
		}
	}

	return versions
}

func (w *DotnetWatcher) getFile(releases []DotnetRelease, version string) (*DotnetFile, string, error) {
	var runtimeVersion string

	switch w.targetType {
	case "sdk":
		for _, r := range releases {
			if r.SDK != nil && r.SDK.Version == version {
				for _, f := range r.SDK.Files {
					if f.Name == "dotnet-sdk-linux-x64.tar.gz" {
						if r.Runtime != nil {
							runtimeVersion = r.Runtime.Version
						}
						return &f, runtimeVersion, nil
					}
				}
			}
		}
	case "runtime":
		for _, r := range releases {
			if r.Runtime != nil && r.Runtime.Version == version {
				for _, f := range r.Runtime.Files {
					if f.Name == "dotnet-runtime-linux-x64.tar.gz" {
						runtimeVersion = version
						return &f, runtimeVersion, nil
					}
				}
			}
		}
	case "aspnetcore":
		for _, r := range releases {
			if r.AspnetcoreRuntime != nil && r.AspnetcoreRuntime.Version == version {
				for _, f := range r.AspnetcoreRuntime.Files {
					if f.Name == "aspnetcore-runtime-linux-x64.tar.gz" {
						runtimeVersion = version
						return &f, runtimeVersion, nil
					}
				}
			}
		}
	}

	return nil, "", fmt.Errorf("file not found for version %s", version)
}

func (w *DotnetWatcher) getChannelVersion(version string) string {
	parts := strings.Split(version, ".")
	if len(parts) >= 2 {
		return strings.Join(parts[0:2], ".")
	}
	return version
}

func (w *DotnetWatcher) uniqueVersions(versions []base.Internal) []base.Internal {
	seen := make(map[string]bool)
	var result []base.Internal

	for _, v := range versions {
		if !seen[v.Ref] {
			seen[v.Ref] = true
			result = append(result, v)
		}
	}

	return result
}

func (w *DotnetWatcher) reverseVersions(versions []base.Internal) []base.Internal {
	result := make([]base.Internal, len(versions))
	for i, v := range versions {
		result[len(versions)-1-i] = v
	}
	return result
}

func (w *DotnetWatcher) downloadFile(downloadURL, destDir, expectedHash string) error {
	resp, err := w.client.Get(downloadURL)
	if err != nil {
		return fmt.Errorf("downloading file: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("reading file: %w", err)
	}

	hash := sha512.Sum512(body)
	gotHash := hex.EncodeToString(hash[:])

	if gotHash != expectedHash {
		return fmt.Errorf("hash mismatch: expected %s, got %s", expectedHash, gotHash)
	}

	filename := filepath.Base(downloadURL)
	destPath := filepath.Join(destDir, filename)

	if err := os.WriteFile(destPath, body, 0644); err != nil {
		return fmt.Errorf("writing file: %w", err)
	}

	return nil
}
