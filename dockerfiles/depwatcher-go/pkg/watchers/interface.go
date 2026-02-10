package watchers

import "github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"

type Watcher interface {
	Check() ([]base.Internal, error)
	In(ref string) (base.Release, error)
}
