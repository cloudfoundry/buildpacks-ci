package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockCorrettoClient struct {
	response string
	err      error
}

func (m *mockCorrettoClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockCorrettoClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestCorrettoWatcher_Check(t *testing.T) {
	mockResp := `[
		{"tag_name": "8.302.08.1", "draft": false, "prerelease": false},
		{"tag_name": "8.292.10.1", "draft": false, "prerelease": false},
		{"tag_name": "11.0.12.7.1", "draft": false, "prerelease": false},
		{"tag_name": "16.0.2.7.1", "draft": false, "prerelease": false},
		{"tag_name": "draft-version", "draft": true, "prerelease": false},
		{"tag_name": "prerelease-version", "draft": false, "prerelease": true}
	]`

	client := &mockCorrettoClient{response: mockResp}
	watcher := NewCorrettoWatcher(client, "corretto", "corretto-8")

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.NotEmpty(t, versions)

	// Should exclude draft and prerelease
	assert.Equal(t, 4, len(versions))

	// Verify version format conversion
	assert.Equal(t, "8.292.10-1", versions[0].Ref)
	assert.Equal(t, "8.302.08-1", versions[1].Ref)
	assert.Equal(t, "11.0.12-7.1", versions[2].Ref)
	assert.Equal(t, "16.0.2-7.1", versions[3].Ref)
}

func TestCorrettoWatcher_Check_InvalidJSON(t *testing.T) {
	client := &mockCorrettoClient{response: "invalid json"}
	watcher := NewCorrettoWatcher(client, "corretto", "corretto-8")

	_, err := watcher.Check()
	assert.Error(t, err)
}

func TestCorrettoWatcher_In(t *testing.T) {
	client := &mockCorrettoClient{}
	watcher := NewCorrettoWatcher(client, "corretto", "corretto-8")

	release, err := watcher.In("8.302.08-1")
	assert.NoError(t, err)
	assert.Equal(t, "8.302.08-1", release.Ref)
	assert.Equal(t, "https://corretto.aws/downloads/resources/8.302.08.1/amazon-corretto-8.302.08.1-linux-x64.tar.gz", release.URL)
}

func TestCorrettoWatcher_In_MultiPartBuildVersion(t *testing.T) {
	client := &mockCorrettoClient{}
	watcher := NewCorrettoWatcher(client, "corretto", "corretto-11")

	release, err := watcher.In("11.0.12-7.1")
	assert.NoError(t, err)
	assert.Equal(t, "11.0.12-7.1", release.Ref)
	assert.Equal(t, "https://corretto.aws/downloads/resources/11.0.12.7.1/amazon-corretto-11.0.12.7.1-linux-x64.tar.gz", release.URL)
}
