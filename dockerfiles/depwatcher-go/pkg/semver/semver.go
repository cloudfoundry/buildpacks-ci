package semver

import (
	"fmt"
	"regexp"
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

var jep322SuffixRegex = regexp.MustCompile(`^((?:\.\d+)+)(?:\+(\d+))?$`)

// parseExtraFields detects metadata of the form ".N[.N...][+B]" which
// represents additional JEP 322 version fields (e.g. ".1" in "17.0.20.1" or
// ".1+2" in "21.0.12.1+2"). SapMachine, Liberica and Zulu use these for
// monthly patch releases, not as pre-release markers. build is -1
// when absent.
func parseExtraFields(metadata string) (fields []int, build int, ok bool) {
	suffixMatch := jep322SuffixRegex.FindStringSubmatch(metadata)
	if suffixMatch == nil {
		return nil, 0, false
	}
	for _, field := range strings.Split(suffixMatch[1][1:], ".") {
		fieldNumber, err := strconv.Atoi(field)
		if err != nil {
			return nil, 0, false
		}
		fields = append(fields, fieldNumber)
	}
	build = -1
	if suffixMatch[2] != "" {
		var err error
		if build, err = strconv.Atoi(suffixMatch[2]); err != nil {
			return nil, 0, false
		}
	}
	return fields, build, true
}

// compareExtraFields compares extra version fields, treating missing fields
// as lower than present ones ("21.0.10" < "21.0.10.0.1"), then build numbers.
func compareExtraFields(leftFields []int, leftBuild int, rightFields []int, rightBuild int) int {
	for fieldIndex := 0; fieldIndex < len(leftFields) && fieldIndex < len(rightFields); fieldIndex++ {
		if leftFields[fieldIndex] != rightFields[fieldIndex] {
			if leftFields[fieldIndex] < rightFields[fieldIndex] {
				return -1
			}
			return 1
		}
	}
	if len(leftFields) != len(rightFields) {
		if len(leftFields) < len(rightFields) {
			return -1
		}
		return 1
	}
	switch {
	case leftBuild < rightBuild:
		return -1
	case leftBuild > rightBuild:
		return 1
	}
	return 0
}

// LessThanJRE orders numeric JRE releases after prereleases, comparing extra
// version fields and then builds (absent < +0 < +1).
func (s *Semver) LessThanJRE(other *Semver) bool {
	if s.Major == other.Major && s.Minor == other.Minor && s.Patch == other.Patch {
		currentFields, currentBuild, currentIsJRE := parseJREMetadata(s.Metadata)
		otherFields, otherBuild, otherIsJRE := parseJREMetadata(other.Metadata)
		if currentIsJRE && otherIsJRE {
			return compareExtraFields(currentFields, currentBuild, otherFields, otherBuild) < 0
		}
		if currentIsJRE {
			return false
		}
		if otherIsJRE {
			return true
		}
	}
	return s.LessThan(other)
}

func parseJREMetadata(metadata string) ([]int, int, bool) {
	if metadata == "" {
		return nil, -1, true
	}
	if buildMatch := jreBuildRegex.FindStringSubmatch(metadata); buildMatch != nil {
		build, err := strconv.Atoi(buildMatch[1])
		return nil, build, err == nil
	}
	return parseExtraFields(metadata)
}

var jreBuildRegex = regexp.MustCompile(`^\+(\d+)$`)

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
func comparePrerelease(leftMetadata, rightMetadata string) bool {
	// Remove leading dash if present (e.g., "-alpha" -> "alpha")
	leftMetadata = strings.TrimPrefix(leftMetadata, "-")
	rightMetadata = strings.TrimPrefix(rightMetadata, "-")

	leftParts := strings.Split(leftMetadata, ".")
	rightParts := strings.Split(rightMetadata, ".")

	// Compare each identifier
	for partIndex := 0; partIndex < len(leftParts) && partIndex < len(rightParts); partIndex++ {
		leftNumber, leftIsNumeric := parseNumeric(leftParts[partIndex])
		rightNumber, rightIsNumeric := parseNumeric(rightParts[partIndex])

		if leftIsNumeric && rightIsNumeric {
			// Both numeric: compare numerically
			if leftNumber != rightNumber {
				return leftNumber < rightNumber
			}
		} else if leftIsNumeric {
			// Numeric < non-numeric
			return true
		} else if rightIsNumeric {
			// Non-numeric > numeric
			return false
		} else {
			// Both non-numeric: compare lexically
			if leftParts[partIndex] != rightParts[partIndex] {
				return leftParts[partIndex] < rightParts[partIndex]
			}
		}
	}

	// If all identifiers are equal, shorter version is less
	return len(leftParts) < len(rightParts)
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
