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
