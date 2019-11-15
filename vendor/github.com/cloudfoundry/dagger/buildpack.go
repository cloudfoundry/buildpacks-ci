package dagger

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/cloudfoundry/dagger/utils"

	"github.com/cloudfoundry/libcfbuildpack/helper"
	"github.com/pkg/errors"
)

var downloadCache sync.Map

func init() {
	rand.Seed(time.Now().UnixNano())
	downloadCache = sync.Map{}
}

func FindBPRoot() (string, error) {
	dir, err := filepath.Abs(".")
	if err != nil {
		return "", err
	}
	for {
		if dir == "/" {
			return "", fmt.Errorf("could not find buildpack.toml in the directory hierarchy")
		}
		// TODO: Take out after transition all cnbs to buildpack.toml.tmpl
		if exist, err := helper.FileExists(filepath.Join(dir, "buildpack.toml")); err != nil {
			return "", err
		} else if exist {
			return dir, nil
		}
		if exist, err := helper.FileExists(filepath.Join(dir, "buildpack.toml.tmpl")); err != nil {
			return "", err
		} else if exist {
			return dir, nil
		}
		dir, err = filepath.Abs(filepath.Join(dir, ".."))
		if err != nil {
			return "", err
		}
	}
}

func PackageBuildpack(root string) (string, error) {
	path, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}

	bpName := fmt.Sprintf("%s_%s", filepath.Base(path), utils.RandStringRunes(8))
	bpPath := filepath.Join(path, bpName)

	cmd := exec.Command("scripts/package.sh")
	cmd.Env = append(os.Environ(), fmt.Sprintf("PACKAGE_DIR=%s", bpPath))
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", err
	}

	return bpPath, nil
}

func PackageCachedBuildpack(root string) (string, string, error) {
	tmp, err := ioutil.TempDir("", "")
	if err != nil {
		return "", "", err
	}

	path := filepath.Join(tmp, filepath.Base(root))
	cmd := exec.Command("scripts/package.sh", "-c", "-v", "0.0.0")
	cmd.Env = append(os.Environ(), fmt.Sprintf("PACKAGE_DIR=%s", path))
	cmd.Dir = root
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()

	return fmt.Sprintf("%s-cached", path), string(out), err
}

func GetLatestBuildpack(name string) (string, error) {
	return GetLatestCommunityBuildpack("cloudfoundry", name)
}

func GetLatestUnpackagedBuildpack(name string) (string, error) {
	return GetLatestUnpackagedCommunityBuildpack("cloudfoundry", name)
}

func DeleteBuildpack(root string) error {
	return os.RemoveAll(root)
}

func GetLatestUnpackagedCommunityBuildpack(org, name string) (string, error) {
	uri := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases/latest", org, name)
	ctx := context.Background()
	client := utils.NewGitClient(ctx)

	release := struct {
		TagName    string `json:"tag_name"`
		TarballURL string `json:"tarball_url"`
	}{}
	request, err := http.NewRequest(http.MethodGet, uri, nil)
	if err != nil {
		return "", err
	}
	if _, err := client.Do(ctx, request, &release); err != nil {
		return "", err
	}

	return downloadAndUnTarBuildpack(release.TarballURL, fmt.Sprintf("%s-cached", name), release.TagName, 1)
}

func GetLatestCommunityBuildpack(org, name string) (string, error) {
	uri := fmt.Sprintf("https://api.github.com/repos/%s/%s/releases/latest", org, name)
	ctx := context.Background()
	client := utils.NewGitClient(ctx)

	release := struct {
		TagName string `json:"tag_name"`
		Assets  []struct {
			BrowserDownloadURL string `json:"browser_download_url"`
		} `json:"assets"`
	}{}
	request, err := http.NewRequest(http.MethodGet, uri, nil)
	if err != nil {
		return "", err
	}
	if _, err := client.Do(ctx, request, &release); err != nil {
		return "", err
	}
	if len(release.Assets) == 0 {
		return "", fmt.Errorf("there are no releases for %s", name)
	}

	return downloadAndUnTarBuildpack(release.Assets[0].BrowserDownloadURL, name, release.TagName, 0)
}

func downloadAndUnTarBuildpack(downloadURL, name, tagName string, level int) (string, error) { //'level' specifies which level of the untarred directory we care about
	contents, found := downloadCache.Load(name + tagName)
	if !found {
		buildpackResp, err := http.Get(downloadURL)
		if err != nil {
			return "", err
		}

		defer buildpackResp.Body.Close()

		contents, err = ioutil.ReadAll(buildpackResp.Body)
		if err != nil {
			return "", err
		}

		if buildpackResp.StatusCode != http.StatusOK {
			return "", errors.Errorf("Erroring Getting buildpack : status %d : %s", buildpackResp.StatusCode, contents)
		}

		downloadCache.Store(name+tagName, contents)
	}

	downloadFile, err := ioutil.TempFile("", "")
	if err != nil {
		return "", err
	}
	defer os.Remove(downloadFile.Name())

	_, err = io.Copy(downloadFile, bytes.NewReader(contents.([]byte)))
	if err != nil {
		return "", err
	}

	dest, err := ioutil.TempDir("", "")
	if err != nil {
		return "", err
	}

	return dest, helper.ExtractTarGz(downloadFile.Name(), dest, level)
}
