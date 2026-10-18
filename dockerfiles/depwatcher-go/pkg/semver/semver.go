package semver

import (
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"
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

// isFourthSegment detects metadata of the form ".\d+" which represents a
// 4th version digit (e.g. ".1" in "17.0.20.1"). SapMachine uses this as a
// stable patch suffix, not a pre-release marker.
func isFourthSegment(metadata string) (int, bool) {
	if len(metadata) < 2 || metadata[0] != '.' {
		return 0, false
	}
	n, err := strconv.Atoi(metadata[1:])
	if err != nil {
		return 0, false
	}
	return n, true
}

// jreMetadataRegex matches JRE metadata after major.minor.patch: optional
// extra JEP 322 fields and an optional numeric build (e.g. "", "+10", ".1",
// ".1+2", ".0.1").
var jreMetadataRegex = regexp.MustCompile(`^((?:\.\d+)*)(?:\+(\d+))?$`)

// parseJREMetadata returns the extra JEP 322 fields and the build number (-1
// when absent). SapMachine, Liberica and Zulu use extra fields for monthly
// patch releases, not as pre-release markers.
func parseJREMetadata(metadata string) (fields []int, build int, ok bool) {
	match := jreMetadataRegex.FindStringSubmatch(metadata)
	if match == nil {
		return nil, 0, false
	}
	for _, field := range strings.Split(match[1], ".")[1:] {
		n, err := strconv.Atoi(field)
		if err != nil {
			return nil, 0, false
		}
		fields = append(fields, n)
	}
	build = -1
	if match[2] != "" {
		var err error
		if build, err = strconv.Atoi(match[2]); err != nil {
			return nil, 0, false
		}
	}
	return fields, build, true
}

// LessThanJRE orders numeric JRE releases after prereleases, comparing extra
// version fields (missing fields are lower: "21.0.10" < "21.0.10.0.1") and
// then builds (absent < +0 < +1).
func (s *Semver) LessThanJRE(other *Semver) bool {
	if s.Major == other.Major && s.Minor == other.Minor && s.Patch == other.Patch {
		sFields, sBuild, sIsJRE := parseJREMetadata(s.Metadata)
		oFields, oBuild, oIsJRE := parseJREMetadata(other.Metadata)
		switch {
		case sIsJRE && oIsJRE:
			if order := slices.Compare(sFields, oFields); order != 0 {
				return order < 0
			}
			return sBuild < oBuild
		case sIsJRE || oIsJRE:
			return oIsJRE
		}
	}
	return s.LessThan(other)
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

	// Handle 4th-segment versions (e.g. "17.0.20.1" > "17.0.20").
	// These are stable patch releases, not pre-releases.
	sBuild, sIsFourth := isFourthSegment(s.Metadata)
	oBuild, oIsFourth := isFourthSegment(other.Metadata)

	if sIsFourth && oIsFourth {
		return sBuild < oBuild
	}
	if sIsFourth {
		return false // s has 4th digit, so s > other
	}
	if oIsFourth {
		return true // other has 4th digit, so s < other
	}

	// Handle pre-release versions according to semver spec:
	// 1.0.0-alpha < 1.0.0-beta < 1.0.0
	// (pre-release versions have lower precedence than release versions)
	if s.Metadata == "" && other.Metadata == "" {
		return false // Equal versions
	}
	if s.Metadata == "" {
		return false // Release version is greater than pre-release
	}
	if other.Metadata == "" {
		return true // Pre-release version is less than release
	}

	// Both have metadata, compare according to semver 2.0.0 spec section 11.4
	return comparePrerelease(s.Metadata, other.Metadata)
}

// comparePrerelease compares pre-release versions according to semver 2.0.0 spec
// Section 11.4: Compare each dot-separated identifier from left to right
// - Numeric identifiers are compared numerically
// - Alphanumeric identifiers are compared lexically
// - Numeric identifiers always have lower precedence than non-numeric
func comparePrerelease(a, b string) bool {
	// Remove leading dash if present (e.g., "-alpha" -> "alpha")
	a = strings.TrimPrefix(a, "-")
	b = strings.TrimPrefix(b, "-")

	aParts := strings.Split(a, ".")
	bParts := strings.Split(b, ".")

	// Compare each identifier
	for i := 0; i < len(aParts) && i < len(bParts); i++ {
		aNum, aIsNum := parseNumeric(aParts[i])
		bNum, bIsNum := parseNumeric(bParts[i])

		if aIsNum && bIsNum {
			// Both numeric: compare numerically
			if aNum != bNum {
				return aNum < bNum
			}
		} else if aIsNum {
			// Numeric < non-numeric
			return true
		} else if bIsNum {
			// Non-numeric > numeric
			return false
		} else {
			// Both non-numeric: compare lexically
			if aParts[i] != bParts[i] {
				return aParts[i] < bParts[i]
			}
		}
	}

	// If all identifiers are equal, shorter version is less
	return len(aParts) < len(bParts)
}

// parseNumeric attempts to parse a string as a numeric identifier
// Returns the number and true if successful, 0 and false otherwise
func parseNumeric(s string) (int, bool) {
	num, err := strconv.Atoi(s)
	if err != nil {
		return 0, false
	}
	return num, true
}

func (s *Semver) IsFinalRelease() bool {
	return s.Metadata == ""
}

func (s *Semver) String() string {
	return fmt.Sprintf("%d.%d.%d", s.Major, s.Minor, s.Patch)
}
