package main_test

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/dagger"

	. "github.com/onsi/gomega"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
)

var (
	folder   string
	stack    string
	repo     string
	fixtures []string
)

var suite = spec.New("Integration", spec.Parallel(), spec.Report(report.Terminal{}))

func init() {
	suite("Integration", testFixtures)
}

func TestFixtures(t *testing.T) {
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

	dagger.SyncParallelOutput(func() {
		suite.Run(t)
	})
}

func testFixtures(t *testing.T, when spec.G, it spec.S) {
	var (
		Expect func(interface{}, ...interface{}) Assertion
	)

	it.Before(func() {
		Expect = NewWithT(t).Expect
	})

	for _, fixture := range fixtures {
		fixture := fixture
		when(fmt.Sprintf("pack build %s", fixture), func() {
			it("should build succesfully", func() {
				imgName := filepath.Base(fixture)
				fmt.Printf("Attempting to build %s\n", imgName)
				packCmd := exec.Command("pack", "build", imgName, "-p", fixture,
					"--builder", fmt.Sprintf("%s:%s", repo, stack), "--no-pull")

				output, err := packCmd.CombinedOutput()
				fmt.Printf("Build Output: \n%s\n", string(output))
				Expect(err).NotTo(HaveOccurred(), "failed to pack build %s: %s", imgName, err)

			})
		})
	}
}
