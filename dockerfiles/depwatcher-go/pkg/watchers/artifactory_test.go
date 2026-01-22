package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockArtifactoryClient struct {
	response string
	err      error
}

func (m *mockArtifactoryClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockArtifactoryClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestArtifactoryWatcher_Check(t *testing.T) {
	mockResp := `{
		"results": [
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
				"path": "com/example/app/1.2.3/app-1.2.3.jar"
			},
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
				"path": "com/example/app/1.2.4/app-1.2.4.jar"
			},
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.3.0-SNAPSHOT/app-1.3.0-SNAPSHOT.jar",
				"path": "com/example/app/1.3.0-SNAPSHOT/app-1.3.0-SNAPSHOT.jar"
			}
		]
	}`

	client := &mockArtifactoryClient{response: mockResp}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
	assert.NoError(t, err)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 3, len(versions))
	assert.Equal(t, "1.2.3", versions[0].Ref)
	assert.Equal(t, "1.2.4", versions[1].Ref)
	assert.Equal(t, "1.3.0-SNAPSHOT", versions[2].Ref)
}

func TestArtifactoryWatcher_Check_WithArtifactPattern(t *testing.T) {
	mockResp := `{
		"results": [
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
				"path": "com/example/app/1.2.3/app-1.2.3.jar"
			},
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3-sources.jar",
				"path": "com/example/app/1.2.3/app-1.2.3-sources.jar"
			},
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
				"path": "com/example/app/1.2.4/app-1.2.4.jar"
			}
		]
	}`

	client := &mockArtifactoryClient{response: mockResp}
	// Only match .jar files that are not sources
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", ".*\\.jar$", "", "")
	assert.NoError(t, err)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	// Should include all .jar files (sources filtering would need more specific pattern)
	assert.GreaterOrEqual(t, len(versions), 2)
}

func TestArtifactoryWatcher_Check_MissingURI(t *testing.T) {
	client := &mockArtifactoryClient{}
	watcher, err := NewArtifactoryWatcher(client, "", "com.example", "app", "libs-release", "", "", "")
	assert.NoError(t, err)

	_, err = watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "uri must be specified")
}

func TestArtifactoryWatcher_Check_MissingGroupID(t *testing.T) {
	client := &mockArtifactoryClient{}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "", "app", "libs-release", "", "", "")
	assert.NoError(t, err)

	_, err = watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "group_id must be specified")
}

func TestArtifactoryWatcher_Check_MissingArtifactID(t *testing.T) {
	client := &mockArtifactoryClient{}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "", "libs-release", "", "", "")
	assert.NoError(t, err)

	_, err = watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "artifact_id must be specified")
}

func TestArtifactoryWatcher_Check_MissingRepository(t *testing.T) {
	client := &mockArtifactoryClient{}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "", "", "", "")
	assert.NoError(t, err)

	_, err = watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "repository must be specified")
}

func TestArtifactoryWatcher_Check_InvalidArtifactPattern(t *testing.T) {
	client := &mockArtifactoryClient{}
	_, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "[invalid", "", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid artifact pattern")
}

func TestArtifactoryWatcher_In(t *testing.T) {
	mockResp := `{
		"results": [
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
				"path": "com/example/app/1.2.3/app-1.2.3.jar"
			},
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.4/app-1.2.4.jar",
				"path": "com/example/app/1.2.4/app-1.2.4.jar"
			}
		]
	}`

	client := &mockArtifactoryClient{response: mockResp}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
	assert.NoError(t, err)

	release, err := watcher.In("1.2.3")
	assert.NoError(t, err)
	assert.Equal(t, "1.2.3", release.Ref)
	assert.Equal(t, "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar", release.URL)
}

func TestArtifactoryWatcher_In_VersionNotFound(t *testing.T) {
	mockResp := `{
		"results": [
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
				"path": "com/example/app/1.2.3/app-1.2.3.jar"
			}
		]
	}`

	client := &mockArtifactoryClient{response: mockResp}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "", "")
	assert.NoError(t, err)

	_, err = watcher.In("9.9.9")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "could not find version")
}

func TestArtifactoryWatcher_In_WithAuth(t *testing.T) {
	mockResp := `{
		"results": [
			{
				"downloadUri": "https://artifactory.example.com/repo/com/example/app/1.2.3/app-1.2.3.jar",
				"path": "com/example/app/1.2.3/app-1.2.3.jar"
			}
		]
	}`

	client := &mockArtifactoryClient{response: mockResp}
	watcher, err := NewArtifactoryWatcher(client, "https://artifactory.example.com", "com.example", "app", "libs-release", "", "user", "pass")
	assert.NoError(t, err)

	release, err := watcher.In("1.2.3")
	assert.NoError(t, err)
	assert.Equal(t, "1.2.3", release.Ref)
}
