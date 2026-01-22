package watchers

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type mockLibericaClient struct {
	response string
	err      error
}

func (m *mockLibericaClient) Get(url string) (*http.Response, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(bytes.NewBufferString(m.response)),
	}, nil
}

func (m *mockLibericaClient) GetWithHeaders(url string, headers http.Header) (*http.Response, error) {
	return m.Get(url)
}

func TestLibericaWatcher_Check(t *testing.T) {
	mockResp := `[
		{
			"featureVersion": 8,
			"interimVersion": 0,
			"updateVersion": 302,
			"buildVersion": 8,
			"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
		},
		{
			"featureVersion": 8,
			"interimVersion": 0,
			"updateVersion": 292,
			"buildVersion": 10,
			"downloadUrl": "https://download.bell-sw.com/java/8u292+10/bellsoft-jdk8u292+10-linux-amd64.tar.gz"
		}
	]`

	client := &mockLibericaClient{response: mockResp}
	watcher := NewLibericaWatcher(client, "8", "jdk", "jdk", "")

	versions, err := watcher.Check()
	assert.NoError(t, err)
	assert.Equal(t, 2, len(versions))
	assert.Equal(t, "8.0.292+10", versions[0].Ref)
	assert.Equal(t, "8.0.302+8", versions[1].Ref)
}

func TestLibericaWatcher_Check_MissingVersion(t *testing.T) {
	client := &mockLibericaClient{}
	watcher := NewLibericaWatcher(client, "", "jdk", "jdk", "")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "version must be specified")
}

func TestLibericaWatcher_Check_MissingProduct(t *testing.T) {
	client := &mockLibericaClient{}
	watcher := NewLibericaWatcher(client, "8", "", "jdk", "")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "product must be specified")
}

func TestLibericaWatcher_Check_MissingType(t *testing.T) {
	client := &mockLibericaClient{}
	watcher := NewLibericaWatcher(client, "8", "jdk", "", "")

	_, err := watcher.Check()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "type must be specified")
}

func TestLibericaWatcher_In(t *testing.T) {
	mockResp := `[
		{
			"featureVersion": 8,
			"interimVersion": 0,
			"updateVersion": 302,
			"buildVersion": 8,
			"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
		}
	]`

	client := &mockLibericaClient{response: mockResp}
	watcher := NewLibericaWatcher(client, "8", "jdk", "jdk", "")

	release, err := watcher.In("8.0.302+8")
	assert.NoError(t, err)
	assert.Equal(t, "8.0.302+8", release.Ref)
	assert.Equal(t, "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz", release.URL)
}

func TestLibericaWatcher_In_VersionNotFound(t *testing.T) {
	mockResp := `[
		{
			"featureVersion": 8,
			"interimVersion": 0,
			"updateVersion": 302,
			"buildVersion": 8,
			"downloadUrl": "https://download.bell-sw.com/java/8u302+8/bellsoft-jdk8u302+8-linux-amd64.tar.gz"
		}
	]`

	client := &mockLibericaClient{response: mockResp}
	watcher := NewLibericaWatcher(client, "8", "jdk", "jdk", "")

	_, err := watcher.In("8.0.999+1")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "could not find release for version")
}
