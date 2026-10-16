package semver_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/semver"
)

var _ = Describe("Semver", func() {
	Describe("Parse", func() {
		Context("when parsing valid semver strings", func() {
			It("parses major.minor.patch", func() {
				sv, err := semver.Parse("3.2.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(3))
				Expect(sv.Minor).To(Equal(2))
				Expect(sv.Patch).To(Equal(1))
				Expect(sv.Metadata).To(Equal(""))
			})

			It("parses with v prefix", func() {
				sv, err := semver.Parse("v3.2.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(3))
				Expect(sv.Minor).To(Equal(2))
				Expect(sv.Patch).To(Equal(1))
			})

			It("parses with metadata", func() {
				sv, err := semver.Parse("3.2.1-beta")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(3))
				Expect(sv.Minor).To(Equal(2))
				Expect(sv.Patch).To(Equal(1))
				Expect(sv.Metadata).To(Equal("-beta"))
			})

			It("parses major.minor only", func() {
				sv, err := semver.Parse("3.2")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(3))
				Expect(sv.Minor).To(Equal(2))
				Expect(sv.Patch).To(Equal(0))
			})

			It("parses major only", func() {
				sv, err := semver.Parse("3")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(3))
				Expect(sv.Minor).To(Equal(0))
				Expect(sv.Patch).To(Equal(0))
			})

			It("preserves original string", func() {
				sv, err := semver.Parse("v3.2.1-beta.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Original).To(Equal("v3.2.1-beta.1"))
			})

			It("parses 4-digit version (SapMachine-style)", func() {
				sv, err := semver.Parse("17.0.20.1")
				Expect(err).NotTo(HaveOccurred())
				Expect(sv.Major).To(Equal(17))
				Expect(sv.Minor).To(Equal(0))
				Expect(sv.Patch).To(Equal(20))
				Expect(sv.Metadata).To(Equal(".1"))
			})
		})

		Context("when parsing invalid strings", func() {
			It("returns an error for non-numeric versions", func() {
				_, err := semver.Parse("abc")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("not a semantic version"))
			})

			It("returns an error for empty strings", func() {
				_, err := semver.Parse("")
				Expect(err).To(HaveOccurred())
			})
		})
	})

	Describe("LessThan", func() {
		It("compares major versions", func() {
			v1, _ := semver.Parse("2.0.0")
			v2, _ := semver.Parse("3.0.0")
			Expect(v1.LessThan(v2)).To(BeTrue())
			Expect(v2.LessThan(v1)).To(BeFalse())
		})

		It("compares minor versions when major is equal", func() {
			v1, _ := semver.Parse("3.1.0")
			v2, _ := semver.Parse("3.2.0")
			Expect(v1.LessThan(v2)).To(BeTrue())
			Expect(v2.LessThan(v1)).To(BeFalse())
		})

		It("compares patch versions when major and minor are equal", func() {
			v1, _ := semver.Parse("3.2.1")
			v2, _ := semver.Parse("3.2.2")
			Expect(v1.LessThan(v2)).To(BeTrue())
			Expect(v2.LessThan(v1)).To(BeFalse())
		})

		It("compares original strings when all numeric parts are equal", func() {
			v1, _ := semver.Parse("3.2.1-alpha")
			v2, _ := semver.Parse("3.2.1-beta")
			Expect(v1.LessThan(v2)).To(BeTrue())
			Expect(v2.LessThan(v1)).To(BeFalse())
		})

		It("returns false when versions are equal", func() {
			v1, _ := semver.Parse("3.2.1")
			v2, _ := semver.Parse("3.2.1")
			Expect(v1.LessThan(v2)).To(BeFalse())
		})

		Context("extra version fields (generic ordering, unchanged from master)", func() {
			DescribeTable("orders a single fourth field as a patch, other extras like pre-release metadata",
				func(leftVersion, rightVersion string, expected bool) {
					leftSemver, err := semver.Parse(leftVersion)
					Expect(err).NotTo(HaveOccurred())
					rightSemver, err := semver.Parse(rightVersion)
					Expect(err).NotTo(HaveOccurred())
					Expect(leftSemver.LessThan(rightSemver)).To(Equal(expected))
				},
				Entry("fourth field newer than bare", "1.29.2.3", "1.29.2", false),
				Entry("bare older than fourth field", "1.29.2", "1.29.2.3", true),
				Entry("fourth fields compared numerically", "1.29.2.3", "1.29.2.10", true),
				Entry("fourth field across patches", "17.0.20.1", "17.0.21", true),
				Entry("extra fields with build older than bare", "1.2.3.4+5", "1.2.3", true),
				Entry("build older than bare", "21.0.12+0", "21.0.12", true),
				Entry("bare not older than build", "21.0.12", "21.0.12+0", false),
			)
		})

		Context("pre-release version comparison", func() {
			It("considers pre-release versions less than release versions", func() {
				preRelease, _ := semver.Parse("1.0.0-alpha")
				release, _ := semver.Parse("1.0.0")
				Expect(preRelease.LessThan(release)).To(BeTrue())
				Expect(release.LessThan(preRelease)).To(BeFalse())
			})

			It("compares pre-release versions lexicographically", func() {
				alpha, _ := semver.Parse("1.0.0-alpha")
				beta, _ := semver.Parse("1.0.0-beta")
				rc, _ := semver.Parse("1.0.0-rc")
				Expect(alpha.LessThan(beta)).To(BeTrue())
				Expect(beta.LessThan(rc)).To(BeTrue())
				Expect(alpha.LessThan(rc)).To(BeTrue())
			})

			It("handles complex pre-release identifiers", func() {
				v1, _ := semver.Parse("1.0.0-alpha.1")
				v2, _ := semver.Parse("1.0.0-alpha.2")
				Expect(v1.LessThan(v2)).To(BeTrue())
			})

			It("compares numeric pre-release identifiers numerically, not lexicographically", func() {
				// This is the key test for semver 2.0.0 spec compliance
				v1, _ := semver.Parse("1.0.0-alpha.2")
				v2, _ := semver.Parse("1.0.0-alpha.10")
				Expect(v1.LessThan(v2)).To(BeTrue())
				Expect(v2.LessThan(v1)).To(BeFalse())

				v3, _ := semver.Parse("1.0.0-2")
				v4, _ := semver.Parse("1.0.0-10")
				Expect(v3.LessThan(v4)).To(BeTrue())
				Expect(v4.LessThan(v3)).To(BeFalse())
			})

			It("considers numeric identifiers less than non-numeric identifiers", func() {
				numeric, _ := semver.Parse("1.0.0-1")
				alpha, _ := semver.Parse("1.0.0-alpha")
				Expect(numeric.LessThan(alpha)).To(BeTrue())
				Expect(alpha.LessThan(numeric)).To(BeFalse())
			})

			It("handles mixed numeric and non-numeric identifiers", func() {
				v1, _ := semver.Parse("1.0.0-alpha.1")
				v2, _ := semver.Parse("1.0.0-alpha.beta")
				Expect(v1.LessThan(v2)).To(BeTrue())
			})

			It("considers shorter pre-release versions less than longer ones when all identifiers match", func() {
				v1, _ := semver.Parse("1.0.0-alpha")
				v2, _ := semver.Parse("1.0.0-alpha.1")
				Expect(v1.LessThan(v2)).To(BeTrue())
				Expect(v2.LessThan(v1)).To(BeFalse())
			})
		})

		Context("backward compatibility", func() {
			DescribeTable("preserves established ordering",
				func(olderVersion, newerVersion string) {
					olderSemver, err := semver.Parse(olderVersion)
					Expect(err).NotTo(HaveOccurred())
					newerSemver, err := semver.Parse(newerVersion)
					Expect(err).NotTo(HaveOccurred())
					Expect(olderSemver.LessThan(newerSemver)).To(BeTrue())
					Expect(newerSemver.LessThan(olderSemver)).To(BeFalse())
				},
				Entry("AppDynamics dash suffix", "25.5.0-1371", "25.5.0"),
			)
		})
	})

	Describe("LessThanJRE", func() {
		DescribeTable("matches JRE buildpack ordering",
			func(olderVersion, newerVersion string) {
				olderSemver, err := semver.Parse(olderVersion)
				Expect(err).NotTo(HaveOccurred())
				newerSemver, err := semver.Parse(newerVersion)
				Expect(err).NotTo(HaveOccurred())
				Expect(olderSemver.LessThanJRE(newerSemver)).To(BeTrue())
				Expect(newerSemver.LessThanJRE(olderSemver)).To(BeFalse())
			},
			Entry("absent build before zero", "21.0.12", "21.0.12+0"),
			Entry("absent build before positive build", "21.0.12", "21.0.12+10"),
			Entry("quarterly rebuild", "21.0.12+9", "21.0.12+10"),
			Entry("Liberica monthly patch", "21.0.12+10", "21.0.12.1+1"),
			Entry("Liberica monthly rebuild", "21.0.12.1+9", "21.0.12.1+10"),
			Entry("Zulu monthly patch", "17.0.20", "17.0.20.1"),
			Entry("SapMachine extra fields", "21.0.10", "21.0.10.0.1"),
			Entry("different feature versions", "17.0.20+10", "21.0.12"),
			Entry("Zulu monthly patches", "17.0.20.1", "17.0.20.2"),
			Entry("monthly patch before next patch version", "17.0.20.1", "17.0.21"),
			Entry("Liberica multi-digit rebuild", "21.0.12.1+2", "21.0.12.1+10"),
			Entry("Liberica next monthly patch", "21.0.12.1+10", "21.0.12.2+1"),
			Entry("monthly patch before next quarterly", "21.0.12.2+1", "21.0.13+1"),
			Entry("absent build before zero with extra fields", "21.0.12.1", "21.0.12.1+0"),
			Entry("fewer extra fields first", "21.0.10.0.1", "21.0.10.1"),
			Entry("SapMachine fields numerically", "21.0.10.0.9", "21.0.10.0.10"),
			Entry("SapMachine builds numerically", "21.0.10.0.1+9", "21.0.10.0.1+10"),
			Entry("prerelease before release", "21.0.12-ea", "21.0.12"),
			Entry("prerelease before numbered release", "21.0.12-ea", "21.0.12+0"),
			Entry("signed suffix is not a build number", "21.0.12+-1", "21.0.12"),
			Entry("double plus suffix is not a build number", "21.0.12++10", "21.0.12+0"),
		)
	})

	Describe("IsFinalRelease", func() {
		It("returns true when there is no metadata", func() {
			sv, _ := semver.Parse("3.2.1")
			Expect(sv.IsFinalRelease()).To(BeTrue())
		})

		It("returns false when there is metadata", func() {
			sv, _ := semver.Parse("3.2.1-beta")
			Expect(sv.IsFinalRelease()).To(BeFalse())
		})
	})

	Describe("String", func() {
		It("returns major.minor.patch format", func() {
			sv, _ := semver.Parse("v3.2.1-beta")
			Expect(sv.String()).To(Equal("3.2.1"))
		})
	})
})

var _ = Describe("Filter", func() {
	Describe("Match", func() {
		Context("when filter has no X", func() {
			It("matches exact version", func() {
				filter := semver.NewFilter("3.2.1")
				sv, _ := semver.Parse("3.2.1")
				Expect(filter.Match(sv)).To(BeTrue())
			})

			It("does not match different version", func() {
				filter := semver.NewFilter("3.2.1")
				sv, _ := semver.Parse("3.2.2")
				Expect(filter.Match(sv)).To(BeFalse())
			})
		})

		Context("when filter has X wildcard", func() {
			It("matches 3.2.X pattern", func() {
				filter := semver.NewFilter("3.2.X")

				sv1, _ := semver.Parse("3.2.0")
				Expect(filter.Match(sv1)).To(BeTrue())

				sv2, _ := semver.Parse("3.2.1")
				Expect(filter.Match(sv2)).To(BeTrue())

				sv3, _ := semver.Parse("3.2.99")
				Expect(filter.Match(sv3)).To(BeTrue())
			})

			It("matches 3.2.x pattern (lowercase)", func() {
				filter := semver.NewFilter("3.2.x")

				sv1, _ := semver.Parse("3.2.0")
				Expect(filter.Match(sv1)).To(BeTrue())

				sv2, _ := semver.Parse("3.2.1")
				Expect(filter.Match(sv2)).To(BeTrue())

				sv3, _ := semver.Parse("3.2.99")
				Expect(filter.Match(sv3)).To(BeTrue())
			})

			It("does not match different minor version", func() {
				filter := semver.NewFilter("3.2.X")
				sv, _ := semver.Parse("3.3.0")
				Expect(filter.Match(sv)).To(BeFalse())
			})

			It("matches 3.X.X pattern", func() {
				filter := semver.NewFilter("3.X.X")

				sv1, _ := semver.Parse("3.0.0")
				Expect(filter.Match(sv1)).To(BeTrue())

				sv2, _ := semver.Parse("3.2.1")
				Expect(filter.Match(sv2)).To(BeTrue())

				sv3, _ := semver.Parse("3.99.99")
				Expect(filter.Match(sv3)).To(BeTrue())
			})

			It("does not match different major version", func() {
				filter := semver.NewFilter("3.X.X")
				sv, _ := semver.Parse("4.0.0")
				Expect(filter.Match(sv)).To(BeFalse())
			})
		})
	})
})
