package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockWildflyClient struct {
	response string
	err      error
}

func (m *mockWildflyClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockWildflyClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestWildflyWatcher_Check(t *testing.T) {
	mockHTML := `<html><body>
		<div class="version-id">26.1.0.Final</div>
		<div class="version-id">26.0.1.Final</div>
		<div class="version-id">25.0.0.Final</div>
	</body></html>`

	client := &mockWildflyClient{response: mockHTML}
	watcher := NewWildflyWatcher(client)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 3, len(versions))
	assert.Equal(t, "25.0.0-Final", versions[0].Ref)
	assert.Equal(t, "26.0.1-Final", versions[1].Ref)
	assert.Equal(t, "26.1.0-Final", versions[2].Ref)
}

func TestWildflyWatcher_In(t *testing.T) {
	client := &mockWildflyClient{}
	watcher := NewWildflyWatcher(client)

	release, err := watcher.In("26.1.0-Final")
	assert.NoError(t, err)
	assert.Equal(t, "26.1.0-Final", release.Ref)
	assert.Equal(t, "https://download.jboss.org/wildfly/26.1.0.Final/wildfly-26.1.0.Final.tar.gz", release.URL)
}

func TestWildflyWatcher_In_InvalidVersion(t *testing.T) {
	client := &mockWildflyClient{}
	watcher := NewWildflyWatcher(client)

	_, err := watcher.In("invalid")
	assert.Error(t, err)
}
