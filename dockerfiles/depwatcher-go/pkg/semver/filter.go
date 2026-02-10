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

	firstXIdx := strings.Index(f.filterString, "X")
	if firstXIdx == -1 {
		return semverString == f.filterString
	}

	prefix := f.filterString[:firstXIdx]
	return strings.HasPrefix(semverString, prefix) && len(f.filterString) <= len(semverString)
}
