package main_test

import (
	"testing"

	. "github.com/cloudfoundry/buildpacks-ci/tasks/cnb/update-cnb-dependency"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"
	"github.com/stretchr/testify/assert"
)

func TestCommitArtifacts(t *testing.T) {
	spec.Run(t, "CommitArtifacts", testCommitArtifacts, spec.Report(report.Terminal{}))
}

func testCommitArtifacts(t *testing.T, when spec.G, it spec.S) {
	when("commit message is empty", func() {
		it("shouldn't add or commit anything", func() {
			assert.Nil(t, CommitArtifacts("", "", ""))
		})
	})
}
