package main

import (
	"log"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/pkg/errors"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("failed to run: %s", err)
	}
	log.Println("succesfully ran")
}

// Problem Statement:
// Display in output of some sort, the time difference between ruby-2.6.5 was released (Oct 1)
// and when it was released on github
// as well as pivnet
// output the date difference
func run() error {
	time, err := FileDate("/Users/pivotal/workspace/public-buildpacks-ci-robots/binary-builds-new/ruby/2.6.5.json")
	if err != nil {
		return errors.Wrap(err, "failed to get date of file")
	}
	log.Println(time)
	return nil
}

func FileDate(path string) (time.Time, error) {
	fileDir := filepath.Dir(path)
	fileName := filepath.Base(path)

	//Running git log -1 --format="%ai" --reverse public-buildpacks-ci-robots/binary-builds-new/ruby/2.6.5.json
	cmd := exec.Command("git", "log", "-1", "--format=\"%aI\"", "--reverse", fileName)
	cmd.Dir = fileDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return time.Time{}, errors.Wrap(err, "failed to run `git log`")
	}

	fileDate, err := time.Parse(time.RFC3339, string(output))
	if err != nil {
		return time.Time{}, errors.Wrap(err, "failed to parse the date")
	}
	return fileDate, nil
}
