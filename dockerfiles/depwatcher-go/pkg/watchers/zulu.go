package watchers

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

type ZuluWatcher struct {
	client  base.HTTPClient
	version string
	typ     string
}

type zuluPackage struct {
	JavaVersion   []int  `json:"java_version"`
	DownloadURL   string `json:"download_url"`
	Name          string `json:"name"`
	Latest        bool   `json:"latest"`
	DistroVersion []int  `json:"distro_version"`
}

func NewZuluWatcher(client base.HTTPClient, version, typ string) *ZuluWatcher {
	return &ZuluWatcher{
		client:  client,
		version: version,
		typ:     typ,
	}
}

func (w *ZuluWatcher) Check() ([]base.Internal, error) {
	if w.version == "" {
		// No version specified — return all available latest versions per major line.
		// This is used by the create-new-line-story job to detect new major versions.
		return w.fetchAllLatestVersions()
	}

	pkg, err := w.fetchLatestPackage()
	if err != nil {
		return nil, err
	}

	version, err := w.parseVersion(pkg.JavaVersion)
	if err != nil {
		return nil, err
	}

	return []base.Internal{{Ref: version}}, nil
}

func (w *ZuluWatcher) In(ref string) (base.Release, error) {
	pkg, err := w.fetchLatestPackage()
	if err != nil {
		return base.Release{}, err
	}

	version, err := w.parseVersion(pkg.JavaVersion)
	if err != nil {
		return base.Release{}, err
	}

	if version != ref {
		return base.Release{}, fmt.Errorf("version mismatch: expected %s, got %s", ref, version)
	}

	return base.Release{
		Ref: ref,
		URL: pkg.DownloadURL,
	}, nil
}

func (w *ZuluWatcher) fetchLatestPackage() (*zuluPackage, error) {
	if w.typ == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	// Map bundle_type to java_package_type
	// bundle_type can be: jdk, jre
	packageType := w.typ

	// Use the new Azul metadata API
	url := fmt.Sprintf("https://api.azul.com/metadata/v1/zulu/packages/?java_version=%s&os=linux&arch=x86&archive_type=tar.gz&java_package_type=%s&latest=true&release_status=ga&availability_types=CA",
		w.version, packageType)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching packages: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var packages []zuluPackage
	if err := json.NewDecoder(resp.Body).Decode(&packages); err != nil {
		return nil, fmt.Errorf("decoding packages: %w", err)
	}

	if len(packages) == 0 {
		return nil, fmt.Errorf("no packages found for java_version=%s, package_type=%s", w.version, packageType)
	}

	// Prefer the standard package over CRaC, FX, musl and i686 variants.
	standard := regexp.MustCompile(`^zulu[\d.]+-ca-` + regexp.QuoteMeta(packageType) + `[\d.]+-linux_x64\.tar\.gz$`)
	for i := range packages {
		if standard.MatchString(packages[i].Name) {
			return &packages[i], nil
		}
	}

	// Return the first package (should be the latest for x64 architecture)
	// Filter for x64 architecture in the name
	for _, pkg := range packages {
		if pkg.Name != "" && strings.HasSuffix(pkg.Name, ".tar.gz") {
			// Prefer x64 over i686 or musl
			name := pkg.Name
			// Check if it's the standard x64 build (not musl or i686)
			if !strings.Contains(name, "musl") && !strings.Contains(name, "i686") {
				return &pkg, nil
			}
		}
	}

	// Fallback to first package if no x64 found
	return &packages[0], nil
}

func (w *ZuluWatcher) fetchAllLatestVersions() ([]base.Internal, error) {
	if w.typ == "" {
		return nil, fmt.Errorf("type must be specified")
	}

	// Map bundle_type to java_package_type
	packageType := w.typ

	// Query without java_version to get all versions
	url := fmt.Sprintf("https://api.azul.com/metadata/v1/zulu/packages/?os=linux&arch=x86&archive_type=tar.gz&java_package_type=%s&latest=true&release_status=ga&availability_types=CA",
		packageType)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("fetching packages: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var packages []zuluPackage
	if err := json.NewDecoder(resp.Body).Decode(&packages); err != nil {
		return nil, fmt.Errorf("decoding packages: %w", err)
	}

	if len(packages) == 0 {
		return nil, fmt.Errorf("no packages found for package_type=%s", packageType)
	}

	// Collect unique versions from all packages
	// Group by major version and take the latest for each
	versionMap := make(map[int]*zuluPackage)
	for i := range packages {
		pkg := &packages[i]
		// Only consider standard x64 builds (not musl or i686)
		if pkg.Name != "" && strings.HasSuffix(pkg.Name, ".tar.gz") &&
			!strings.Contains(pkg.Name, "musl") && !strings.Contains(pkg.Name, "i686") {

			if len(pkg.JavaVersion) >= 3 {
				majorVersion := pkg.JavaVersion[0]
				// Keep the latest version for each major version
				if existing, exists := versionMap[majorVersion]; !exists {
					versionMap[majorVersion] = pkg
				} else {
					// Compare versions to keep the latest
					if w.isNewerVersion(pkg.JavaVersion, existing.JavaVersion) {
						versionMap[majorVersion] = pkg
					}
				}
			}
		}
	}

	// Convert to Internal list
	var internals []base.Internal
	for _, pkg := range versionMap {
		version, err := w.parseVersion(pkg.JavaVersion)
		if err != nil {
			continue
		}
		internals = append(internals, base.Internal{Ref: version})
	}

	return base.SortJREVersions(internals), nil
}

func (w *ZuluWatcher) isNewerVersion(v1, v2 []int) bool {
	// Compare version arrays
	for i := 0; i < len(v1) && i < len(v2); i++ {
		if v1[i] > v2[i] {
			return true
		}
		if v1[i] < v2[i] {
			return false
		}
	}
	return len(v1) > len(v2)
}

func (w *ZuluWatcher) parseVersion(versionParts []int) (string, error) {
	if len(versionParts) < 3 {
		return "", fmt.Errorf("version must have three components or more: got %d", len(versionParts))
	}
	// Monthly patch releases have a 4th JEP 322 field (e.g. 17.0.20.1).
	parts := make([]string, len(versionParts))
	for i, p := range versionParts {
		parts[i] = strconv.Itoa(p)
	}
	return strings.Join(parts, "."), nil
}

func (w *ZuluWatcher) name(uri string) string {
	return filepath.Base(uri)
}
