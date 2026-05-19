package watchers

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"fmt"
	"io"
	"strings"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

const sealightsLatestURL = "https://agents.sealights.co/sealights-java/sealights-java-latest.zip"
const sealightsDownloadBase = "https://agents.sealights.co/sealights-java/sealights-java-%s.zip"
const sealightsVersionFile = "sealights-java-version.txt"

type SealightsAgentWatcher struct {
	client base.HTTPClient
}

func NewSealightsAgentWatcher(client base.HTTPClient) *SealightsAgentWatcher {
	return &SealightsAgentWatcher{client: client}
}

func (w *SealightsAgentWatcher) Check() ([]base.Internal, error) {
	version, err := w.fetchLatestVersion()
	if err != nil {
		return nil, err
	}
	return []base.Internal{{Ref: version}}, nil
}

func (w *SealightsAgentWatcher) In(ref string) (base.Release, error) {
	url := fmt.Sprintf(sealightsDownloadBase, ref)

	resp, err := w.client.Get(url)
	if err != nil {
		return base.Release{}, fmt.Errorf("failed to download SeaLights agent: %w", err)
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

func (w *SealightsAgentWatcher) fetchLatestVersion() (string, error) {
	resp, err := w.client.Get(sealightsLatestURL)
	if err != nil {
		return "", fmt.Errorf("failed to fetch SeaLights latest zip: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read SeaLights latest zip: %w", err)
	}

	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("failed to open SeaLights zip: %w", err)
	}

	for _, f := range zr.File {
		if f.Name == sealightsVersionFile {
			rc, err := f.Open()
			if err != nil {
				return "", fmt.Errorf("failed to open %s: %w", sealightsVersionFile, err)
			}
			defer rc.Close()

			versionBytes, err := io.ReadAll(rc)
			if err != nil {
				return "", fmt.Errorf("failed to read %s: %w", sealightsVersionFile, err)
			}

			version := strings.TrimSpace(string(versionBytes))
			if version == "" {
				return "", fmt.Errorf("empty version in %s", sealightsVersionFile)
			}
			return version, nil
		}
	}

	return "", fmt.Errorf("%s not found in SeaLights latest zip", sealightsVersionFile)
}
