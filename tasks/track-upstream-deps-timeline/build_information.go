package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/pkg/errors"
)

type BuildInformation struct {
	TrackerStoryID int `json:"tracker_story_id"`
	CreatedAt      time.Time
}

func NewBuildInformation(path string) (BuildInformation, error) {
	fileDir := filepath.Dir(path)
	fileName := filepath.Base(path)

	binaryBuilds := BuildInformation{}
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		return BuildInformation{}, errors.Wrap(err, fmt.Sprintf("failed to read file at: %s", path))
	}
	if err := json.Unmarshal(contents, &binaryBuilds); err != nil {
		return BuildInformation{}, errors.Wrap(err, fmt.Sprintf("failed to parse binary build from %s", string(contents)))
	}

	//Running git log -1 --format="%aI" --reverse PATH
	cmd := exec.Command("git", "log", "-1", "--format=\"%aI\"", "--reverse", fileName)
	cmd.Dir = fileDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return BuildInformation{}, errors.Wrap(err, "failed to run `git log`")
	}
	timeString := strings.TrimSpace(string(bytes.ReplaceAll(output, []byte("\""), []byte(""))))

	fileDate, err := time.Parse(time.RFC3339, timeString)
	if err != nil {
		return BuildInformation{}, errors.Wrap(err, "failed to parse the date")
	}
	binaryBuilds.CreatedAt = fileDate
	return binaryBuilds, nil
}
