package main

import (
	"os/exec"

	"github.com/pkg/errors"
)

func CommitArtifacts(commitMessage string) error {
	if commitMessage == "" {
		return nil
	}

	output, err := exec.Command("git", "-C", "artifacts", "add", "buildpack.toml").CombinedOutput()
	if err != nil {
		return errors.Wrapf(err, "failed to add artifacts: %s", string(output))
	}

	output, err = exec.Command("git", "-C", "artifacts", "commit", "-m", commitMessage).CombinedOutput()
	if err != nil {
		return errors.Wrapf(err, "failed to commit artifacts: %s", string(output))
	}
	return nil
}
