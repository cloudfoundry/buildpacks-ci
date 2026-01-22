package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockSkyWalkingClient struct {
	responses map[string]string
	err       error
}

func (m *mockSkyWalkingClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}

	response := m.responses[url]
	if response == "" {
		response = m.responses["default"]
	}

	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(response)),
	}, nil
}

func (m *mockSkyWalkingClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestSkyWalkingWatcher_Check(t *testing.T) {
	mockHTML := `<html><body>
		<div class="card-body">
			<div class="title-box"><div class="card-title">Java Agent</div></div>
			<div class="dropdown-header">v8.11.0</div>
		</div>
		<div class="card-body">
			<div class="title-box"><div class="card-title">Other Component</div></div>
			<div class="dropdown-header">v8.10.0</div>
		</div>
	</body></html>`

	client := &mockSkyWalkingClient{responses: map[string]string{"default": mockHTML}}
	watcher := NewSkyWalkingWatcher(client)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 1, len(versions))
	assert.Equal(t, "8.11.0", versions[0].Ref)
}

func TestSkyWalkingWatcher_In(t *testing.T) {
	mirrorHTML := `<html><body>
		<div class="container">
			<p><a><strong>https://downloads.apache.org/skywalking/java-agent/8.11.0/apache-skywalking-java-agent-8.11.0.tgz</strong></a></p>
		</div>
	</body></html>`

	client := &mockSkyWalkingClient{responses: map[string]string{"default": mirrorHTML}}
	watcher := NewSkyWalkingWatcher(client)

	release, err := watcher.In("8.11.0")
	assert.NoError(t, err)
	assert.Equal(t, "8.11.0", release.Ref)
	assert.Contains(t, release.URL, "skywalking")
}

func TestSkyWalkingWatcher_In_FallbackURL(t *testing.T) {
	// Empty mirror HTML - should fallback to archive URL
	mockHTML := `<html><body></body></html>`

	client := &mockSkyWalkingClient{responses: map[string]string{"default": mockHTML}}
	watcher := NewSkyWalkingWatcher(client)

	release, err := watcher.In("8.11.0")
	assert.NoError(t, err)
	assert.Equal(t, "8.11.0", release.Ref)
	assert.Equal(t, "https://archive.apache.org/dist/skywalking/java-agent/8.11.0/apache-skywalking-java-agent-8.11.0.tgz", release.URL)
}
