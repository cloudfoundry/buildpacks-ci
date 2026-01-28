package semver

import (
	"fmt"
	"regexp"
	"strconv"
)

type Semver struct {
	Original string
	Major    int
	Minor    int
	Patch    int
	Metadata string
}

func Parse(version string) (*Semver, error) {
	re := regexp.MustCompile(`^v?(\d+)(\.(\d+))?(\.(\d+))?(.+)?$`)
	matches := re.FindStringSubmatch(version)

	if matches == nil {
		return nil, fmt.Errorf("not a semantic version: %q", version)
	}

	major, _ := strconv.Atoi(matches[1])
	minor := 0
	if matches[3] != "" {
		minor, _ = strconv.Atoi(matches[3])
	}
	patch := 0
	if matches[5] != "" {
		patch, _ = strconv.Atoi(matches[5])
	}
	metadata := ""
	if matches[6] != "" {
		metadata = matches[6]
	}

	return &Semver{
		Original: version,
		Major:    major,
		Minor:    minor,
		Patch:    patch,
		Metadata: metadata,
	}, nil
}

func (s *Semver) LessThan(other *Semver) bool {
	if s.Major != other.Major {
		return s.Major < other.Major
	}
	if s.Minor != other.Minor {
		return s.Minor < other.Minor
	}
	if s.Patch != other.Patch {
		return s.Patch < other.Patch
	}
	return s.Original < other.Original
}

func (s *Semver) IsFinalRelease() bool {
	return s.Metadata == ""
}

func (s *Semver) String() string {
	return fmt.Sprintf("%d.%d.%d", s.Major, s.Minor, s.Patch)
}
