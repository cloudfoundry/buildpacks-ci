package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockZuluClient struct {
	response string
	err      error
}

func (m *mockZuluClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockZuluClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestZuluWatcher_Check(t *testing.T) {
	mockResp := `{
		"jdk_version": [8, 0, 302],
		"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
	}`

	client := &mockZuluClient{response: mockResp}
	watcher := NewZuluWatcher(client, "8", "jdk")

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(versions))
	assert.Equal(t, "8.0.302", versions[0].Ref)
}

func TestZuluWatcher_Check_MissingVersion(t *testing.T) {
	client := &mockZuluClient{}
	watcher := NewZuluWatcher(client, "", "jdk")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "version must be specified")
}

func TestZuluWatcher_Check_MissingType(t *testing.T) {
	client := &mockZuluClient{}
	watcher := NewZuluWatcher(client, "8", "")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "type must be specified")
}

func TestZuluWatcher_Check_InvalidVersionComponents(t *testing.T) {
	mockResp := `{
		"jdk_version": [8, 0],
		"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
	}`

	client := &mockZuluClient{response: mockResp}
	watcher := NewZuluWatcher(client, "8", "jdk")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "version must have three components")
}

func TestZuluWatcher_In(t *testing.T) {
	mockResp := `{
		"jdk_version": [8, 0, 302],
		"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
	}`

	client := &mockZuluClient{response: mockResp}
	watcher := NewZuluWatcher(client, "8", "jdk")

	release, err := watcher.In("8.0.302")
	assert.NoError(t, err)
	assert.Equal(t, "8.0.302", release.Ref)
	assert.Equal(t, "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz", release.URL)
}

func TestZuluWatcher_In_VersionMismatch(t *testing.T) {
	mockResp := `{
		"jdk_version": [8, 0, 302],
		"url": "https://cdn.azul.com/zulu/bin/zulu8.56.0.21-ca-jdk8.0.302-linux_x64.tar.gz"
	}`

	client := &mockZuluClient{response: mockResp}
	watcher := NewZuluWatcher(client, "8", "jdk")

	_, err := watcher.In("8.0.999")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "version mismatch")
}
