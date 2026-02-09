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
