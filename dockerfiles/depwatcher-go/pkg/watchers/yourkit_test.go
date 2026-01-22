package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockYourKitClient struct {
	response string
	err      error
}

func (m *mockYourKitClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockYourKitClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestYourKitWatcher_Check(t *testing.T) {
	mockHTML := `<html><body>
		<a href="/yjp/2022/YourKit-JavaProfiler-2022.9-b238-x64.zip">Download</a>
		<a href="/yjp/2022/YourKit-JavaProfiler-2022.3-b237-x64.zip">Download</a>
		<a href="/yjp/2021/YourKit-JavaProfiler-2021.11-b236-x64.zip">Download</a>
	</body></html>`

	client := &mockYourKitClient{response: mockHTML}
	watcher := NewYourKitWatcher(client)

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 3, len(versions))
}

func TestYourKitWatcher_In(t *testing.T) {
	client := &mockYourKitClient{}
	watcher := NewYourKitWatcher(client)

	release, err := watcher.In("2022.9.238")
	assert.NoError(t, err)
	assert.Equal(t, "2022.9.238", release.Ref)
	assert.Equal(t, "https://download.yourkit.com/yjp/2022.9/YourKit-JavaProfiler-2022.9-b238-x64.zip", release.URL)
}
