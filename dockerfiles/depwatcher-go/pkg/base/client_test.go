package base_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/buildpacks-ci/depwatcher-go/pkg/base"
)

var _ = Describe("HTTPClientImpl", func() {
	var client *base.HTTPClientImpl

	BeforeEach(func() {
		client = base.NewHTTPClient(false)
	})

	Describe("Get", func() {
		var server *httptest.Server

		AfterEach(func() {
			if server != nil {
				server.Close()
			}
		})

		Context("when the request succeeds", func() {
			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`{"version":"1.0.0"}`))
				}))
			})

			It("returns the response", func() {
				resp, err := client.Get(server.URL)
				Expect(err).NotTo(HaveOccurred())
				Expect(resp.StatusCode).To(Equal(http.StatusOK))

				body, _ := io.ReadAll(resp.Body)
				Expect(string(body)).To(Equal(`{"version":"1.0.0"}`))
			})
		})

		Context("when the server returns a redirect", func() {
			BeforeEach(func() {
				redirected := false
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					if !redirected {
						redirected = true
						http.Redirect(w, r, "/redirected", http.StatusFound)
						return
					}
					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`redirected`))
				}))
			})

			It("follows the redirect", func() {
				resp, err := client.Get(server.URL)
				Expect(err).NotTo(HaveOccurred())
				Expect(resp.StatusCode).To(Equal(http.StatusOK))

				body, _ := io.ReadAll(resp.Body)
				Expect(string(body)).To(Equal(`redirected`))
			})
		})

		Context("when OAuth token is set", func() {
			BeforeEach(func() {
				os.Setenv("OAUTH_AUTHORIZATION_TOKEN", "test-token-123")

				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					auth := r.Header.Get("Authorization")
					if auth == "token test-token-123" {
						w.WriteHeader(http.StatusOK)
						w.Write([]byte(`authorized`))
					} else {
						w.WriteHeader(http.StatusUnauthorized)
					}
				}))
			})

			AfterEach(func() {
				os.Unsetenv("OAUTH_AUTHORIZATION_TOKEN")
			})

			It("includes the OAuth token in the Authorization header", func() {
				resp, err := client.Get(server.URL)
				Expect(err).NotTo(HaveOccurred())
				Expect(resp.StatusCode).To(Equal(http.StatusOK))

				body, _ := io.ReadAll(resp.Body)
				Expect(string(body)).To(Equal(`authorized`))
			})
		})

		Context("when the server returns an error status", func() {
			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusNotFound)
				}))
			})

			It("returns an error", func() {
				_, err := client.Get(server.URL)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("404"))
			})
		})
	})

	Describe("GetWithHeaders", func() {
		var server *httptest.Server

		AfterEach(func() {
			if server != nil {
				server.Close()
			}
		})

		Context("when custom headers are provided", func() {
			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					if r.Header.Get("X-Custom-Header") == "custom-value" {
						w.WriteHeader(http.StatusOK)
						w.Write([]byte(`custom headers work`))
					} else {
						w.WriteHeader(http.StatusBadRequest)
					}
				}))
			})

			It("includes the custom headers", func() {
				headers := http.Header{}
				headers.Add("X-Custom-Header", "custom-value")

				resp, err := client.GetWithHeaders(server.URL, headers)
				Expect(err).NotTo(HaveOccurred())
				Expect(resp.StatusCode).To(Equal(http.StatusOK))

				body, _ := io.ReadAll(resp.Body)
				Expect(string(body)).To(Equal(`custom headers work`))
			})
		})
	})
})

var _ = Describe("GetSHA256", func() {
	var server *httptest.Server

	AfterEach(func() {
		if server != nil {
			server.Close()
		}
	})

	Context("when downloading and hashing a file", func() {
		BeforeEach(func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("test content"))
			}))
		})

		It("returns the correct SHA256 hash", func() {
			client := base.NewHTTPClient(false)
			hash, err := base.GetSHA256(client, server.URL)
			Expect(err).NotTo(HaveOccurred())
			Expect(hash).To(Equal("6ae8a75555209fd6c44157c0aed8016e763ff435a19cf186f76863140143ff72"))
		})
	})
})

var _ = Describe("Types", func() {
	Describe("Internal", func() {
		It("has a Ref field", func() {
			internal := base.Internal{Ref: "1.2.3"}
			Expect(internal.Ref).To(Equal("1.2.3"))
		})
	})

	Describe("Release", func() {
		It("has Ref, URL, and SHA256 fields", func() {
			release := base.Release{
				Ref:    "1.2.3",
				URL:    "https://example.com/release.tar.gz",
				SHA256: "abcd1234",
			}
			Expect(release.Ref).To(Equal("1.2.3"))
			Expect(release.URL).To(Equal("https://example.com/release.tar.gz"))
			Expect(release.SHA256).To(Equal("abcd1234"))
		})
	})
})
