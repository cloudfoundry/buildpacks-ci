package semver

import "strings"

type Filter struct {
	filterString string
}

func NewFilter(filterString string) *Filter {
	return &Filter{filterString: filterString}
}

func (f *Filter) Match(semver *Semver) bool {
	semverString := semver.String()

	// Support both uppercase X and lowercase x for wildcard
	firstXIdx := strings.IndexAny(f.filterString, "Xx")
	if firstXIdx == -1 {
		return semverString == f.filterString
	}

	prefix := f.filterString[:firstXIdx]
	return strings.HasPrefix(semverString, prefix) && len(f.filterString) <= len(semverString)
}
