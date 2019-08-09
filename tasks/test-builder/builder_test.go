package main_test

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

var (
	folder   string
	stack    string
	repo     string
	fixtures []string
)

func init() {
	if len(os.Args) < 2 {
		log.Fatalf("Provide the full path to the testfolder as a test arguments\nExample: go test -args test/folder/path\n")
	}

	folder = os.Args[1]

	stack = os.Getenv("STACK")
	repo = os.Getenv("REPO")
	if stack == "" || repo == "" {
		log.Fatalf("The STACK or REPO environment variable is empty. Exiting.\n")
	}

	var err error
	fixtures, err = filepath.Glob(filepath.Join(folder, "*"))

	if err != nil {
		log.Fatalf("Could not glob %s\n", folder)
	}
}

func TestFixtures(t *testing.T) {
	for _, fixture := range fixtures {
		fixture := fixture
		t.Run(fmt.Sprintf("pack build %s", fixture), func(t *testing.T) {
			t.Parallel()

			imgName := filepath.Base(fixture)
			packCmd := exec.Command("pack", "build", imgName, "-p", filepath.Join("..", "..", "..", "cnb-builder", fixture),
				"--builder", fmt.Sprintf("%s:%s", repo, stack), "--no-pull")

			out, err := packCmd.CombinedOutput()
			if err != nil {
				t.Errorf("failed to pack build %s: %s", imgName, err.Error())
			}

			fmt.Println(string(out))
		})
	}
}
