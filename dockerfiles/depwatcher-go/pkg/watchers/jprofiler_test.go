package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockJProfilerClient struct {
	response string
	err      error
}

func (m *mockJProfilerClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockJProfilerClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestJProfilerWatcher_Check(t *testing.T) {
	mockHTML := `<html><body>
		<div class="release-heading">Release 13.0.3 (Build 13033)</div>
		<div class="release-heading">Release 13.0.2 (Build 13024)</div>
		<div class="release-heading">Release 12.0.4 (Build 12048)</div>
	</body></html>`

	client := &mockJProfilerClient{response: mockHTML}
	watcher := NewJProfilerWatcher(client)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 3, len(versions))
	assert.Equal(t, "12.0.4", versions[0].Ref)
	assert.Equal(t, "13.0.2", versions[1].Ref)
	assert.Equal(t, "13.0.3", versions[2].Ref)
}

func TestJProfilerWatcher_In(t *testing.T) {
	client := &mockJProfilerClient{}
	watcher := NewJProfilerWatcher(client)

	release, err := watcher.In("13.0.3")
	assert.NoError(t, err)
	assert.Equal(t, "13.0.3", release.Ref)
	assert.Equal(t, "https://download-gcdn.ej-technologies.com/jprofiler/jprofiler_linux_13_0_3.tar.gz", release.URL)
}

func TestJProfilerWatcher_In_NoPatch(t *testing.T) {
	client := &mockJProfilerClient{}
	watcher := NewJProfilerWatcher(client)

	release, err := watcher.In("13.0.0")
	assert.NoError(t, err)
	assert.Equal(t, "13.0.0", release.Ref)
	assert.Equal(t, "https://download-gcdn.ej-technologies.com/jprofiler/jprofiler_linux_13_0.tar.gz", release.URL)
}
