package watchers_test

import (
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/watchers"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAppDynamicsWatcher_Check(t *testing.T) {
	t.Run("Check returns latest java agent version", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfilelatest/": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"download_path": "https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip",
							"filetype": "java",
							"version": "23.11.0.35669",
							"sha256_checksum": "abc123def456"
						}
					]`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "java", "user", "pass")
		versions, err := watcher.Check()

		require.NoError(t, err)
		require.Len(t, versions, 1)
		assert.Equal(t, "23.11.0-35669", versions[0].Ref)
	})

	t.Run("Check returns latest machine agent version", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfilelatest/": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"download_path": "https://download.appdynamics.com/download/prox/download-file/machine/23.11.0.3826/appdynamics-machine-agent-23.11.0.3826.zip",
							"filetype": "machine",
							"version": "23.11.0.3826",
							"sha256_checksum": "def456ghi789"
						}
					]`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "machine", "user", "pass")
		versions, err := watcher.Check()

		require.NoError(t, err)
		require.Len(t, versions, 1)
		assert.Equal(t, "23.11.0-3826", versions[0].Ref)
	})

	t.Run("Check returns latest php-tar agent version", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfilelatest/": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"download_path": "https://download.appdynamics.com/download/prox/download-file/php-tar/23.10.0.6006/appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2",
							"filetype": "php-tar",
							"version": "23.10.0.6006",
							"sha256_checksum": "ghi789jkl012"
						}
					]`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "php-tar", "user", "pass")
		versions, err := watcher.Check()

		require.NoError(t, err)
		require.Len(t, versions, 1)
		assert.Equal(t, "23.10.0-6006", versions[0].Ref)
	})

	t.Run("Check returns error for unknown agent type", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfilelatest/": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`[
						{
							"download_path": "https://example.com/agent.zip",
							"filetype": "java",
							"version": "23.11.0.35669",
							"sha256_checksum": "abc123def456"
						}
					]`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "unknown", "user", "pass")
		_, err := watcher.Check()

		require.Error(t, err)
		assert.Contains(t, err.Error(), "no version found for agent type unknown")
	})
}

func TestAppDynamicsWatcher_In(t *testing.T) {
	t.Run("In returns java agent release details", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfile/?apm_os=linux&version=23.11.0.35669&apm=java": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`{
						"count": 1,
						"results": [
							{
								"download_path": "https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip",
								"filetype": "java",
								"version": "23.11.0.35669",
								"sha256_checksum": "abc123def456"
							}
						]
					}`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "java", "user", "pass")
		release, err := watcher.In("23.11.0-35669")

		require.NoError(t, err)
		assert.Equal(t, "23.11.0-35669", release.Ref)
		assert.Equal(t, "https://download.appdynamics.com/download/prox/download-file/sun-jvm/23.11.0.35669/AppServerAgent-23.11.0.35669.zip", release.URL)
		assert.Equal(t, "abc123def456", release.SHA256)
	})

	t.Run("In returns php-tar agent release details", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{
				"https://download.appdynamics.com/download/downloadfile/?apm_os=linux&version=23.10.0.6006&apm=php&filetype=tar": {
					StatusCode: http.StatusOK,
					Body: io.NopCloser(strings.NewReader(`{
						"count": 1,
						"results": [
							{
								"download_path": "https://download.appdynamics.com/download/prox/download-file/php-tar/23.10.0.6006/appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2",
								"filetype": "php-tar",
								"version": "23.10.0.6006",
								"sha256_checksum": "ghi789jkl012"
							}
						]
					}`)),
				},
			},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "php-tar", "user", "pass")
		release, err := watcher.In("23.10.0-6006")

		require.NoError(t, err)
		assert.Equal(t, "23.10.0-6006", release.Ref)
		assert.Contains(t, release.URL, "appdynamics-php-agent-x64-linux-23.10.0.6006.tar.bz2")
		assert.Equal(t, "ghi789jkl012", release.SHA256)
	})

	t.Run("In handles invalid version format", func(t *testing.T) {
		mockClient := &appdMockHTTPClient{
			responses: map[string]*http.Response{},
		}

		watcher := watchers.NewAppDynamicsWatcher(mockClient, "java", "user", "pass")
		_, err := watcher.In("invalid")

		require.Error(t, err)
		assert.Contains(t, err.Error(), "invalid version format")
	})
}

func TestAppDynamicsVersionConversion(t *testing.T) {
	mockClient := &appdMockHTTPClient{
		responses: map[string]*http.Response{
			"https://download.appdynamics.com/download/downloadfilelatest/": {
				StatusCode: http.StatusOK,
				Body: io.NopCloser(strings.NewReader(`[
					{
						"filetype": "java",
						"version": "24.1.0.1234",
						"download_path": "https://example.com/agent.zip",
						"sha256_checksum": "abc123"
					}
				]`)),
			},
		},
	}

	watcher := watchers.NewAppDynamicsWatcher(mockClient, "java", "user", "pass")
	versions, err := watcher.Check()

	require.NoError(t, err)
	require.Len(t, versions, 1)
	// Verify conversion from X.Y.Z.W to X.Y.Z-W
	assert.Equal(t, "24.1.0-1234", versions[0].Ref)
}

// appdMockHTTPClient implements base.HTTPClient for testing
type appdMockHTTPClient struct {
	responses map[string]*http.Response
	base.HTTPClient
}

func (m *appdMockHTTPClient) Get(url string) (*http.Response, error) {
	if resp, ok := m.responses[url]; ok {
		return resp, nil
	}
	return &http.Response{
		StatusCode: http.StatusNotFound,
		Body:       io.NopCloser(strings.NewReader("")),
	}, nil
}

func (m *appdMockHTTPClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}
