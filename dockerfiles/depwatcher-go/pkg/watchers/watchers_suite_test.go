package watchers_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestWatchers(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Watchers Suite")
}
