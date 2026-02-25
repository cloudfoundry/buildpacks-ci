# Implementation Plan: Go Rewrite of binary-builder + build task

**Status:** Proposal — not yet started  
**Replaces:** `binary-builder/cflinuxfs4/` + `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/`  
**Goal:** A single Go binary that handles all dependency builds for any stack, where adding a new stack (cflinuxfs5, cflinuxfs6, …) requires only a new YAML config file — no code changes.

**Related documents:**
- [`docs/cflinuxfs5-investigation.md`](cflinuxfs5-investigation.md) — stack-specific code findings, risk table
- [`docs/recipes/compiled-recipes.md`](recipes/compiled-recipes.md) — detailed spec for Ruby, Python, Node, Go, nginx, R, JRuby, HTTPD, libunwind, libgdiplus
- [`docs/recipes/php-recipe.md`](recipes/php-recipe.md) — detailed spec for PHP + all ~35 extension types
- [`docs/recipes/passthrough-recipes.md`](recipes/passthrough-recipes.md) — detailed spec for all direct-download/repack deps
- [`docs/recipes/known-bugs.md`](recipes/known-bugs.md) — bugs in the Ruby code that the Go rewrite must fix

---

## 1. Why a Rewrite Is Justified

The current system has stack-specific knowledge scattered across **two repositories** and **~15 files**:

```
buildpacks-ci/tasks/build-binary-new-cflinuxfs4/
  builder.rb              ← gfortran-11 paths, gcc-12 PPA, ruby bootstrap URL
  binary_builder_wrapper.rb ← hardcoded 'binary-builder/cflinuxfs4'

binary-builder/cflinuxfs4/
  recipe/php_meal.rb      ← apt package list, libldap_r symlink
  recipe/php_recipe.rb    ← libmcrypt path
  recipe/python.rb        ← libdb-dev, --force-yes
  recipe/jruby_meal.rb    ← bionic JDK URL
  recipe/httpd_meal.rb    ← libcjose-dev
  lib/openssl_replace.rb  ← OpenSSL 1.1.0g
  ... and more
```

There is no formal contract between the two repos. They communicate via `exec` and filesystem paths. Adding cflinuxfs5 means copying ~30 files across two repos and hunting down every Ubuntu-version-specific line.

The root cause: **stack-specific knowledge is code, not data.**

The fix: **make stack config data (YAML), make build logic code (Go).**

---

## 2. Design Principles

1. **Stack config is data.** Every Ubuntu-version-specific value lives in a `stacks/{stack}.yaml` file. No stack names appear in Go source code.
2. **One binary, all stacks.** A single compiled Go binary handles any stack. The Concourse task just passes `--stack cflinuxfs5`.
3. **One repository.** Everything moves into `binary-builder/`. The separate `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/` task directory is replaced by a thin shell wrapper that calls the Go binary.
4. **Explicit interfaces.** Each recipe implements a `Recipe` interface. The `Stack` struct is injected — no global state.
5. **Testable without Docker.** Pure functions, no side effects, injectable command runners. Unit tests run without a container.

---

## 3. Repository Structure

```
binary-builder/
├── cmd/
│   └── binary-builder/
│       └── main.go               # CLI entry point (cobra or flag)
├── internal/
│   ├── recipe/
│   │   ├── recipe.go             # Recipe interface + registry
│   │   ├── ruby.go               # portile + libffi
│   │   ├── python.go             # portile + tcl/tk deb + openssl replace
│   │   ├── node.go               # portile + python3 + GCC setup
│   │   ├── go_recipe.go          # bootstrap go download + make.bash
│   │   ├── nginx.go              # portile + openssl replace + PIC/PIE flags
│   │   ├── nginx_static.go       # same as nginx, PIE flags
│   │   ├── openresty.go          # portile + no GPG (TODO)
│   │   ├── httpd.go              # APR + APR-Iconv + APR-Util + HTTPD + mod_auth_openidc
│   │   ├── jruby.go              # JDK download (stack config URL) + Maven + source compile
│   │   ├── bundler.go            # setup_ruby + gem install + shebang replacement
│   │   ├── ruby.go               # portile (binary_builder recipe)
│   │   ├── r.go                  # configure/make + R packages + gfortran CopyLibs
│   │   ├── libunwind.go          # configure/make/make install
│   │   ├── libgdiplus.go         # git clone + autogen + make
│   │   ├── dep.go                # binary_builder recipe
│   │   ├── glide.go              # binary_builder recipe
│   │   ├── godep.go              # binary_builder recipe
│   │   ├── hwc.go                # cross-compile for Windows via mingw-w64
│   │   ├── pip.go                # pip3 download + bundle setuptools + wheel
│   │   ├── pipenv.go             # pip3 download + bundle 7 dependencies
│   │   ├── setuptools.go         # direct download + strip top-level (tar.gz or zip)
│   │   ├── yarn.go               # direct download + strip v prefix + strip top-level
│   │   ├── bower.go              # direct download (npm tarball)
│   │   ├── rubygems.go           # direct download + strip top-level
│   │   ├── dotnet_sdk.go         # download + prune ./shared/* + inject RuntimeVersion.txt
│   │   ├── dotnet_runtime.go     # download + prune ./dotnet
│   │   ├── dotnet_aspnetcore.go  # download + prune ./dotnet + ./shared/Microsoft.NETCore.App
│   │   ├── miniconda.go          # URL passthrough (no file move; sets out_data url+sha256)
│   │   └── passthrough.go        # tomcat, composer, appdynamics, appdynamics_java,
│   │                             # skywalking_agent, openjdk, zulu, sapmachine,
│   │                             # jprofiler_profiler, your_kit_profiler
│   ├── php/
│   │   ├── extensions.go         # extension YAML merge logic
│   │   ├── extensions_test.go
│   │   └── common_recipes.go     # all ~30 PHP extension recipe types
│   ├── stack/
│   │   ├── stack.go              # Stack struct + loader
│   │   └── stack_test.go
│   ├── apt/
│   │   ├── apt.go                # apt-get wrapper
│   │   └── apt_test.go
│   ├── compiler/
│   │   ├── gcc.go                # GCC/g++ setup + update-alternatives
│   │   ├── gfortran.go           # gfortran setup + CopyLibs
│   │   └── compiler_test.go
│   ├── archive/
│   │   ├── archive.go            # tar/zip create + strip helpers
│   │   └── archive_test.go
│   ├── fetch/
│   │   ├── fetch.go              # HTTP download + checksum verify + redirect follow
│   │   └── fetch_test.go
│   ├── portile/
│   │   ├── portile.go            # mini_portile2 equivalent in Go
│   │   └── portile_test.go
│   ├── artifact/
│   │   ├── artifact.go           # naming, SHA256, S3 URL construction
│   │   └── artifact_test.go
│   ├── output/
│   │   ├── build_output.go       # writes + git-commits builds JSON
│   │   ├── dep_metadata.go       # writes dep-metadata JSON
│   │   └── output_test.go
│   ├── gpg/
│   │   ├── gpg.go                # GPG signature verification (used by nginx, nginx-static)
│   │   └── gpg_test.go
│   └── source/
│       ├── source_input.go       # parses source/data.json (both formats)
│       └── source_input_test.go
├── stacks/
│   ├── cflinuxfs4.yaml           # Ubuntu 22.04 stack config
│   └── cflinuxfs5.yaml           # Ubuntu 24.04 stack config
├── php_extensions/
│   ├── php8-base-extensions.yml  # moved from buildpacks-ci task
│   ├── php81-extensions-patch.yml
│   ├── php82-extensions-patch.yml
│   └── php83-extensions-patch.yml
├── go.mod
├── go.sum
└── Makefile
```

### Concourse task (thin wrapper)

```
buildpacks-ci/tasks/build-binary/
├── build.yml       # declares Docker image from stack config, inputs/outputs
└── run.sh          # just: binary-builder/bin/binary-builder --stack $STACK ...
```

---

## 4. Stack Config Schema

```yaml
# stacks/cflinuxfs4.yaml
name: cflinuxfs4
ubuntu_version: "22.04"
ubuntu_codename: jammy
docker_image: cloudfoundry/cflinuxfs4

ruby_bootstrap:
  url: https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz
  sha256: e4311262...
  install_dir: /opt/ruby

compilers:
  gfortran:
    version: 11
    bin: /usr/bin/x86_64-linux-gnu-gfortran-11
    lib_path: /usr/lib/gcc/x86_64-linux-gnu/11
    packages:
      - gfortran
      - libgfortran-12-dev
  gcc:
    version: 12
    packages:
      - gcc-12
      - g++-12
    ppa: ppa:ubuntu-toolchain-r/test

apt_packages:
  php_build:
    - automake
    - firebird-dev
    - libaspell-dev
    - libc-client2007e-dev
    - libcurl4-openssl-dev
    - libdb-dev
    - libedit-dev
    - libenchant-2-dev
    - libexpat1-dev
    - libgdbm-dev
    - libgeoip-dev
    - libgmp-dev
    - libgpgme11-dev
    - libjpeg-dev
    - libkrb5-dev
    - libldap2-dev
    - libmagickwand-dev
    - libmagickcore-dev
    - libmaxminddb-dev
    - libmcrypt-dev
    - libmemcached-dev
    - libonig-dev
    - libpng-dev
    - libpspell-dev
    - librecode-dev
    - libsasl2-dev
    - libsnmp-dev
    - libsqlite3-dev
    - libssh2-1-dev
    - libssl-dev
    - libtidy-dev
    - libtool
    - libwebp-dev
    - libxml2-dev
    - libzip-dev
    - libzookeeper-mt-dev
    - snmp-mibs-downloader
    - sqlite3
    - unixodbc-dev
  r_build:
    - gfortran
    - libbz2-dev
    - liblzma-dev
    - libpcre++-dev
    - libpcre2-dev
    - libcurl4-openssl-dev
    - libsodium-dev
    - libharfbuzz-dev
    - libfribidi-dev
    - default-jre
    - libgfortran-12-dev
    - libfreetype6-dev
    - libpng-dev
    - libtiff5-dev
    - libjpeg-dev
    - libwebp-dev
  ruby_build:
    - libffi-dev
  python_build:
    - libdb-dev
    - libgdbm-dev
    - tk8.6-dev
  node_build: []  # gcc handled via compilers.gcc above
  httpd_build:
    - libldap2-dev
    - libjansson-dev
    - libcjose-dev
    - libhiredis-dev
  libgdiplus_build:
    - automake
    - libtool
    - libglib2.0-dev
    - libcairo2-dev

php_symlinks:
  - src: /usr/include/x86_64-linux-gnu/curl
    dst: /usr/local/include/curl
  - src: /usr/include/x86_64-linux-gnu/gmp.h
    dst: /usr/include/gmp.h
  - src: /usr/lib/x86_64-linux-gnu/libldap.so
    dst: /usr/lib/libldap.so
  - src: /usr/lib/x86_64-linux-gnu/libldap_r.so   # removed in cflinuxfs5
    dst: /usr/lib/libldap_r.so

jruby:
  jdk_url: https://java-buildpack.cloudfoundry.org/openjdk-jdk/bionic/x86_64/openjdk-jdk-1.8.0_242-bionic.tar.gz
  jdk_sha256: dcb9fea2fc3a9b003031874ed17aa5d5a7ebbe397b276ecc8c814633003928fe
  jdk_install_dir: /opt/java

python:
  tcl_version: "8.6"
  use_force_yes: true   # deprecated apt flag; false on 24.04
```

```yaml
# stacks/cflinuxfs5.yaml
name: cflinuxfs5
ubuntu_version: "24.04"
ubuntu_codename: noble
docker_image: cloudfoundry/cflinuxfs5

ruby_bootstrap:
  url: https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_linux_x64_cflinuxfs5_XXXX.tgz
  sha256: XXXX
  install_dir: /opt/ruby

compilers:
  gfortran:
    version: 14
    bin: /usr/bin/x86_64-linux-gnu-gfortran-14
    lib_path: /usr/lib/gcc/x86_64-linux-gnu/14
    packages:
      - gfortran
      - libgfortran-14-dev
  gcc:
    version: 14
    packages:
      - gcc-14
      - g++-14
    ppa: ""   # no PPA needed; gcc-14 native on 24.04

apt_packages:
  php_build:
    - automake
    - firebird-dev
    - libaspell-dev
    - libc-client2007e-dev
    - libcurl4-openssl-dev
    - libdb5.3-dev              # renamed from libdb-dev on 24.04
    - libedit-dev
    - libenchant-2-dev
    - libexpat1-dev
    - libgdbm-dev
    - libgeoip-dev
    - libgmp-dev
    - libgpgme11-dev
    - libjpeg-dev
    - libkrb5-dev
    - libldap2-dev
    - libmagickwand-dev
    - libmagickcore-dev
    - libmaxminddb-dev
    - libmcrypt-dev
    - libmemcached-dev
    - libonig-dev
    - libpng-dev
    - libpspell-dev
    - librecode-dev
    - libsasl2-dev
    - libsnmp-dev
    - libsqlite3-dev
    - libssh2-1-dev
    - libssl-dev
    - libtidy-dev
    - libtool
    - libwebp-dev
    - libxml2-dev
    - libzip-dev
    # libzookeeper-mt-dev omitted — not available on 24.04
    - snmp-mibs-downloader
    - sqlite3
    - unixodbc-dev
  r_build:
    - gfortran
    - libbz2-dev
    - liblzma-dev
    - libpcre2-dev               # libpcre++-dev dropped on 24.04
    - libcurl4-openssl-dev
    - libsodium-dev
    - libharfbuzz-dev
    - libfribidi-dev
    - default-jre
    - libgfortran-14-dev
    - libfreetype6-dev
    - libpng-dev
    - libtiff-dev                # renamed from libtiff5-dev on 24.04
    - libjpeg-dev
    - libwebp-dev
  ruby_build:
    - libffi-dev
  python_build:
    - libdb5.3-dev
    - libgdbm-dev
    - tk8.6-dev
  node_build: []
  httpd_build:
    - libldap2-dev
    - libjansson-dev
    # libcjose-dev omitted — needs verification on 24.04
    - libhiredis-dev
  libgdiplus_build:
    - automake
    - libtool
    - libglib2.0-dev
    - libcairo2-dev

php_symlinks:
  - src: /usr/include/x86_64-linux-gnu/curl
    dst: /usr/local/include/curl
  - src: /usr/include/x86_64-linux-gnu/gmp.h
    dst: /usr/include/gmp.h
  - src: /usr/lib/x86_64-linux-gnu/libldap.so
    dst: /usr/lib/libldap.so
  # libldap_r removed — dropped in OpenLDAP 2.6 (Ubuntu 22.04+)

jruby:
  jdk_url: https://java-buildpack.cloudfoundry.org/openjdk-jdk/noble/x86_64/openjdk-jdk-1.8.0_XXX-noble.tar.gz
  jdk_sha256: XXXX
  jdk_install_dir: /opt/java

python:
  tcl_version: "8.6"
  use_force_yes: false  # --force-yes deprecated; use --yes on 24.04
```

---

## 5. Core Go Interfaces

### 5.1 Recipe Interface

```go
// internal/recipe/recipe.go

type Recipe interface {
    // Name returns the dependency name (e.g. "ruby", "php")
    Name() string

    // Cook performs the full build: download, configure, compile, install.
    Cook(ctx context.Context, s stack.Stack, src source.Input) error

    // ArchiveFiles returns glob patterns of files to pack into the artifact tarball.
    ArchiveFiles() []string

    // ArchivePathName is the top-level directory name inside the tarball ("" for flat).
    ArchivePathName() string

    // ArchiveFilename returns the intermediate output filename before renaming.
    // e.g. "ruby-3.3.6-linux-x64.tgz"
    ArchiveFilename(version string) string
}
```

### 5.2 Stack Struct

```go
// internal/stack/stack.go

type GfortranConfig struct {
    Version  int      `yaml:"version"`
    Bin      string   `yaml:"bin"`
    LibPath  string   `yaml:"lib_path"`
    Packages []string `yaml:"packages"`
}

type GCCConfig struct {
    Version  int      `yaml:"version"`
    Packages []string `yaml:"packages"`
    PPA      string   `yaml:"ppa"`
}

type CompilerConfig struct {
    Gfortran GfortranConfig `yaml:"gfortran"`
    GCC      GCCConfig      `yaml:"gcc"`
}

type RubyBootstrap struct {
    URL        string `yaml:"url"`
    SHA256     string `yaml:"sha256"`
    InstallDir string `yaml:"install_dir"`
}

type JRubyConfig struct {
    JDKURL        string `yaml:"jdk_url"`
    JDKSHA256     string `yaml:"jdk_sha256"`
    JDKInstallDir string `yaml:"jdk_install_dir"`
}

type PythonConfig struct {
    TCLVersion  string `yaml:"tcl_version"`
    UseForceYes bool   `yaml:"use_force_yes"`
}

type Symlink struct {
    Src string `yaml:"src"`
    Dst string `yaml:"dst"`
}

type Stack struct {
    Name           string              `yaml:"name"`
    UbuntuVersion  string              `yaml:"ubuntu_version"`
    UbuntuCodename string              `yaml:"ubuntu_codename"`
    DockerImage    string              `yaml:"docker_image"`
    RubyBootstrap  RubyBootstrap       `yaml:"ruby_bootstrap"`
    Compilers      CompilerConfig      `yaml:"compilers"`
    AptPackages    map[string][]string `yaml:"apt_packages"`
    PHPSymlinks    []Symlink           `yaml:"php_symlinks"`
    JRuby          JRubyConfig         `yaml:"jruby"`
    Python         PythonConfig        `yaml:"python"`
}

// Load reads a stack YAML file from the stacks/ directory.
func Load(stacksDir, name string) (*Stack, error)
```

### 5.3 CommandRunner Interface (for testability)

```go
// internal/runner/runner.go

type Runner interface {
    Run(name string, args ...string) error
    RunWithEnv(env map[string]string, name string, args ...string) error
    RunInDir(dir string, name string, args ...string) error
    Output(name string, args ...string) (string, error)
}

// RealRunner executes commands for production use.
type RealRunner struct{}

// FakeRunner records calls for unit tests.
type FakeRunner struct {
    Calls []Call
}

type Call struct {
    Name string
    Args []string
    Env  map[string]string
    Dir  string
}
```

---

## 6. Key Internal Packages

### `internal/portile`

Go equivalent of `mini_portile2`. Manages the download → extract → configure → compile → install lifecycle for autoconf-based software:

```go
type Portile struct {
    Name    string
    Version string
    URL     string
    SHA256  string
    Prefix  string          // --prefix=
    Options []string        // extra configure flags
    Runner  runner.Runner
    Fetcher fetch.Fetcher
}

func (p *Portile) Cook(ctx context.Context) error
func (p *Portile) TmpPath() string     // /tmp/{arch}/ports/{name}/{version}
func (p *Portile) PortPath() string    // TmpPath/port
```

### `internal/apt`

```go
type APT struct {
    Runner runner.Runner
}

func (a *APT) Update(ctx context.Context) error
func (a *APT) Install(ctx context.Context, packages ...string) error
func (a *APT) AddPPA(ctx context.Context, ppa string) error
// InstallReinstall runs apt-get -d install --reinstall (used by python for tcl/tk debs)
func (a *APT) InstallReinstall(ctx context.Context, useForceYes bool, packages ...string) error
```

### `internal/compiler`

```go
type GCC struct {
    Config stack.GCCConfig
    APT    *apt.APT
    Runner runner.Runner
}

// Setup installs gcc, adds PPA if configured, sets up update-alternatives.
func (g *GCC) Setup(ctx context.Context) error

type Gfortran struct {
    Config stack.GfortranConfig
    APT    *apt.APT
    Runner runner.Runner
}

// Setup installs gfortran packages for the stack.
func (g *Gfortran) Setup(ctx context.Context) error

// CopyLibs copies the stack-specific gfortran libs into the target directory.
func (g *Gfortran) CopyLibs(ctx context.Context, targetLib, targetBin string) error
```

### `internal/fetch`

```go
type Fetcher interface {
    Download(ctx context.Context, url, dest string, checksum Checksum) error
    ReadBody(ctx context.Context, url string) ([]byte, error)
}

type Checksum struct {
    Algorithm string // "sha256", "sha512", "md5", "sha1"
    Value     string
}
```

### `internal/gpg`

```go
// VerifySignature downloads file + .asc, imports all public keys, runs gpg --verify.
// Used by nginx and nginx-static.
func VerifySignature(ctx context.Context, fileURL, signatureURL string, publicKeyURLs []string, runner runner.Runner) error
```

### `internal/archive`

```go
// Pack creates a tarball from the given glob patterns.
func Pack(outputPath, pathName string, globs []string) error

// PackZip creates a zip archive.
func PackZip(outputPath string, globs []string) error

// StripTopLevelDir re-archives a tarball without its top-level directory.
func StripTopLevelDir(path string) error

// StripFiles removes matching files from inside a tarball.
func StripFiles(path string, pattern string) error

// StripIncorrectWordsYAML removes incorrect_words.yaml from tar and nested jars.
// Used by jruby to strip bundled YAML files that confuse spell checkers.
func StripIncorrectWordsYAML(path string) error
```

### `internal/artifact`

```go
type Artifact struct {
    Name    string
    Version string
    OS      string   // "linux", "windows"
    Arch    string   // "x64", "noarch", "x86-64"
    Stack   string   // "cflinuxfs4", "cflinuxfs5", "any-stack"
}

// Filename returns "name_version_os_arch_stack_sha256prefix.ext"
func (a Artifact) Filename(sha256 string, ext string) string

// S3URL returns the canonical S3 URL for the artifact.
// The filename is URL-safe-encoded: '+' is replaced with '%2B' to prevent
// AWS S3 permission denied errors (S3 interprets unencoded '+' as space).
// See: https://github.com/cloudfoundry/buildpacks-ci/pull/553
func (a Artifact) S3URL(filename string) string
```

### `internal/source`

```go
// Input represents the source/data.json Concourse resource.
// Handles both legacy and modern JSON formats.
type Input struct {
    Name         string
    URL          string
    Version      string
    MD5          string
    SHA256       string
    SHA512       string
    SHA1         string
    GitCommitSHA string
    Repo         string
    Type         string
}

func FromFile(path string) (*Input, error)
func (i *Input) PrimaryChecksum() fetch.Checksum
```

### `internal/php`

```go
// ExtensionSet is the loaded + patched set of PHP extensions.
type ExtensionSet struct {
    NativeModules []Extension `yaml:"native_modules"`
    Extensions    []Extension `yaml:"extensions"`
}

type Extension struct {
    Name    string `yaml:"name"`
    Version string `yaml:"version"`
    MD5     string `yaml:"md5"`
    Klass   string `yaml:"klass"`
}

// Load reads the base YAML and applies all applicable patch YAMLs.
func Load(extensionsDir, phpMajor, phpMinor string) (*ExtensionSet, error)

// RecipeFor returns the appropriate recipe builder for a PHP extension klass name.
func RecipeFor(klass string) (ExtensionRecipe, error)
```

---

## 7. Recipe Implementations

See the dedicated recipe reference documents for full per-recipe specs:

- **Compiled recipes** (Ruby, Python, Node, Go, nginx, openresty, R, JRuby, HTTPD, libunwind, libgdiplus, bundler, dep/glide/godep, hwc) → [`docs/recipes/compiled-recipes.md`](recipes/compiled-recipes.md)
- **PHP recipe** (full meal with ~35 extension types) → [`docs/recipes/php-recipe.md`](recipes/php-recipe.md)
- **Passthrough/repack recipes** (pip, pipenv, setuptools, yarn, bower, rubygems, dotnet-sdk/runtime/aspnetcore, miniconda, tomcat, composer, appdynamics, appdynamics-java, skywalking-agent, openjdk, zulu, sapmachine, jprofiler-profiler, your-kit-profiler) → [`docs/recipes/passthrough-recipes.md`](recipes/passthrough-recipes.md)

Key stack-specific patterns used across compiled recipes:

### Stack injection (all compiled recipes)

```go
// No recipe has any if/switch on stack name.
// All Ubuntu-version-specific values come from the injected stack.Stack.

func (r *RRecipe) Cook(ctx context.Context, s stack.Stack, src source.Input) error {
    // apt install from s.AptPackages["r_build"] — fully stack-driven
    apt := apt.New(runner)
    if err := apt.Install(ctx, s.AptPackages["r_build"]...); err != nil {
        return err
    }
    // gfortran version from s.Compilers.Gfortran — no hardcoded version numbers
    gf := compiler.NewGfortran(s.Compilers.Gfortran, runner)
    if err := gf.Setup(ctx); err != nil {
        return err
    }
    // ... compile R, install packages ...
    if err := gf.CopyLibs(ctx, rLibDir, rBinDir); err != nil {
        return err
    }
    return nil
}
```

### GCC (Node recipe)

```go
func (n *NodeRecipe) Cook(ctx context.Context, s stack.Stack, src source.Input) error {
    gcc := compiler.NewGCC(s.Compilers.GCC, runner)
    // adds PPA only when s.Compilers.GCC.PPA != ""
    // cflinuxfs4: adds ppa:ubuntu-toolchain-r/test, installs gcc-12
    // cflinuxfs5: skips PPA, installs gcc-14 (native)
    if err := gcc.Setup(ctx); err != nil {
        return err
    }
    // ... rest of Node build ...
}
```

### PHP (stack-driven packages + symlinks)

```go
func (p *PHPRecipe) Cook(ctx context.Context, s stack.Stack, src source.Input) error {
    apt := apt.New(runner)
    // All packages from stack config — no hardcoded list in Go code
    if err := apt.Install(ctx, s.AptPackages["php_build"]...); err != nil {
        return err
    }
    // Symlinks from stack config — cflinuxfs5 YAML omits libldap_r entry
    for _, link := range s.PHPSymlinks {
        os.Symlink(link.Src, link.Dst)
    }
    // ... rest of PHP build ...
}
```

---

## 8. CLI Interface

```
binary-builder build \
  --name ruby \
  --version 3.3.6 \
  --sha256 abc123... \
  --stack cflinuxfs5 \
  --stacks-dir /path/to/stacks \
  --php-extensions-dir /path/to/php_extensions \
  --artifacts-dir /path/to/artifacts \
  --builds-dir /path/to/builds-artifacts \
  --dep-metadata-dir /path/to/dep-metadata \
  --source-file /path/to/source/data.json \
  [--skip-commit]
```

Or with a source file (Concourse mode):
```
binary-builder build \
  --stack cflinuxfs5 \
  --source-file source/data.json \
  --stacks-dir binary-builder/stacks \
  --artifacts-dir artifacts \
  --builds-dir builds-artifacts \
  --dep-metadata-dir dep-metadata
```

---

## 9. Concourse Task (Thin Wrapper)

```yaml
# buildpacks-ci/tasks/build-binary/build.yml
platform: linux

image_resource:
  type: docker-image
  source:
    repository: #@ "{}-image".format(data.values.stack)  # ytt: cflinuxfs4 or cflinuxfs5
    tag: latest

inputs:
  - name: binary-builder
  - name: buildpacks-ci
  - name: source
  - name: builds

outputs:
  - name: artifacts
  - name: builds-artifacts
  - name: dep-metadata

params:
  STACK: ~
  SKIP_COMMIT: "false"

run:
  path: buildpacks-ci/tasks/build-binary/run.sh
```

```bash
#!/bin/bash
# buildpacks-ci/tasks/build-binary/run.sh
set -euo pipefail

binary-builder/bin/binary-builder build \
  --stack "$STACK" \
  --source-file source/data.json \
  --stacks-dir binary-builder/stacks \
  --php-extensions-dir binary-builder/php_extensions \
  --artifacts-dir artifacts \
  --builds-dir builds-artifacts \
  --dep-metadata-dir dep-metadata \
  ${SKIP_COMMIT:+--skip-commit}
```

The Go binary is pre-compiled as part of the `binary-builder` resource and checked in as `binary-builder/bin/binary-builder` (compiled for `linux/amd64`). Or it is compiled inside the container at task start via `go build ./cmd/binary-builder`.

---

## 10. Implementation Phases

### Phase 1 — Scaffold & Stack Config (Week 1)
**Goal:** Go module with stack loading, no build logic yet.

- [ ] `go mod init github.com/cloudfoundry/binary-builder`
- [ ] `internal/stack/stack.go` — Stack struct, YAML loader, validation
- [ ] `stacks/cflinuxfs4.yaml` — transcribe all cflinuxfs4 values from existing Ruby code
- [ ] `stacks/cflinuxfs5.yaml` — transcribe all cflinuxfs5 values (known differences)
- [ ] `internal/source/source_input.go` — port both JSON format parsers from Ruby
- [ ] `internal/fetch/fetch.go` — HTTP download with checksum verification + redirect following
- [ ] `internal/runner/runner.go` — Runner interface + RealRunner + FakeRunner (with Call struct)
- [ ] `internal/apt/apt.go` — apt-get wrapper including `InstallReinstall`
- [ ] `internal/gpg/gpg.go` — GPG signature verification
- [ ] Unit tests for all of the above

**Exit criteria:** `go test ./...` passes; stack YAML files load and validate correctly.

---

### Phase 2 — Core Infrastructure (Week 2)
**Goal:** Archive, artifact naming, portile, compiler helpers.

- [ ] `internal/portile/portile.go` — mini_portile2 equivalent (download/extract/configure/compile/install lifecycle)
- [ ] `internal/archive/archive.go` — tar/zip pack, strip-top-level, strip-files-from-tar, strip-incorrect-words-yaml
- [ ] `internal/artifact/artifact.go` — filename construction, SHA256, S3 URL
- [ ] `internal/compiler/gcc.go` — GCC setup (reads from Stack.Compilers.GCC, adds PPA if non-empty, sets update-alternatives)
- [ ] `internal/compiler/gfortran.go` — gfortran setup + CopyLibs (reads Stack.Compilers.Gfortran)
- [ ] `internal/output/build_output.go` — writes JSON, git add/commit
- [ ] `internal/output/dep_metadata.go` — writes metadata JSON
- [ ] Unit tests for all of the above (FakeRunner for system calls)

**Exit criteria:** `go test ./...` passes; archive round-trips work correctly.

---

### Phase 3 — Simple & Passthrough Recipes (Week 3–4)
**Goal:** Port all recipes except PHP, R, JRuby, HTTPD.

#### Compiled recipes (use portile or custom compile):
- [ ] `internal/recipe/libunwind.go` — configure/make/make install from pre-downloaded tarball
- [ ] `internal/recipe/libgdiplus.go` — git clone + autogen + make; sets CXXFLAGS/CFLAGS
- [ ] `internal/recipe/bundler.go` — setup_ruby (bootstrap from stack config), gem install, shebang replacement
- [ ] `internal/recipe/ruby.go` — portile + `ruby_build` apt packages
- [ ] `internal/recipe/go_recipe.go` — bootstrap Go download, strip top-level, make.bash
- [ ] `internal/recipe/node.go` — portile + python3/pip setup + GCC setup (from stack config)
- [ ] `internal/recipe/python.go` — portile + tcl/tk .deb extraction + openssl replace + `python_build` apt
- [ ] `internal/recipe/nginx.go` — GPG verify + portile + openssl replace + PIC flags
- [ ] `internal/recipe/nginx_static.go` — same as nginx, PIE flags, static=true (no top-level dir in tar)
- [ ] `internal/recipe/openresty.go` — configure/make (no GPG — TODO carried forward)
- [ ] `internal/recipe/dep.go`, `glide.go`, `godep.go` — binary_builder delegate
- [ ] `internal/recipe/hwc.go` — cross-compile for Windows via mingw-w64

#### Passthrough / repack recipes (see `docs/recipes/passthrough-recipes.md` for full specs):
- [ ] `internal/recipe/pip.go` — pip3 download + bundle setuptools + wheel (CVE-2026-24049 pin)
- [ ] `internal/recipe/pipenv.go` — pip3 download + bundle 7 dependencies (pytest-runner, setuptools_scm, parver, wheel, invoke, flit_core, hatch-vcs)
- [ ] `internal/recipe/setuptools.go` — direct download + strip top-level (tar.gz or zip)
- [ ] `internal/recipe/yarn.go` — direct download + strip `v` prefix + strip top-level
- [ ] `internal/recipe/bower.go` — direct download (npm tarball, stack-namespaced artifact)
- [ ] `internal/recipe/rubygems.go` — direct download + strip top-level
- [ ] `internal/recipe/dotnet_sdk.go` — download + prune `./shared/*` + inject `RuntimeVersion.txt` + xz compress
- [ ] `internal/recipe/dotnet_runtime.go` — download + prune `./dotnet` + xz compress
- [ ] `internal/recipe/dotnet_aspnetcore.go` — download + prune `./dotnet` + `./shared/Microsoft.NETCore.App` + xz compress
- [ ] `internal/recipe/miniconda.go` — URL passthrough only (no file move; sets `out_data.url` + `out_data.sha256` directly)
- [ ] `internal/recipe/passthrough.go` — generic handler for: `tomcat`, `composer`, `appdynamics`, `appdynamics_java`, `skywalking_agent`, `openjdk`, `zulu`, `sapmachine`, `jprofiler_profiler`, `your_kit_profiler`
- [ ] `cmd/binary-builder/main.go` — CLI wiring (cobra/flag), recipe registry, dispatch, artifact output

**Exit criteria:** `binary-builder build --name ruby --version 3.3.6 --sha256 ... --stack cflinuxfs4` runs end-to-end in the cflinuxfs4 Docker container and produces the correct artifact. All passthrough recipes produce artifacts with correct filenames and checksums.

---

### Phase 4 — PHP & Extensions (Week 4–5)
**Goal:** Port the most complex recipe — PHP with its ~35 extension types.

- [ ] `internal/php/extensions.go` — base YAML load + patch merge logic (port from `extensions_helper.rb`)
- [ ] `internal/php/common_recipes.go` — all ~30 extension recipe types (PeclRecipe, FakePeclRecipe, HiredisRecipe, RabbitMQRecipe, ImagickRecipe, etc.)
- [ ] `internal/recipe/php.go` — full PHPMeal: apt install (from stack config), symlinks (from stack config), native modules, extensions, setup_tar lib copying
- [ ] `php_extensions/` YAML files moved from buildpacks-ci into binary-builder repo
- [ ] Integration test: build PHP 8.3 in cflinuxfs4 container, verify extensions present

**Exit criteria:** PHP builds successfully for cflinuxfs4 with the same extensions as the Ruby version. `out_data[:sub_dependencies]` is populated correctly.

---

### Phase 5 — R, JRuby, HTTPD (Week 5–6)
**Goal:** Port the remaining complex recipes.

- [ ] `internal/recipe/r.go` — R build, devtools, Rserve/forecast/shiny/plumber R packages, gfortran CopyLibs; reads 4 sub-dep source inputs from Concourse resource dirs
- [ ] `internal/recipe/jruby.go` — JDK download (URL from `stack.JRuby.JDKURL`), Maven build, JRuby source compile; `StripIncorrectWordsYAML` post-processing; version augmented with ruby version suffix
- [ ] `internal/recipe/httpd.go` — APR/APR-Iconv/APR-Util/HTTPD/mod_auth_openidc; dynamic GitHub version lookup for APR components

**Exit criteria:** All recipes compile and pass unit tests with FakeRunner.

---

### Phase 6 — cflinuxfs5 Validation (Week 6–7)
**Goal:** Verify all recipes work against Ubuntu 24.04.

- [ ] Populate `stacks/cflinuxfs5.yaml` with verified Ubuntu 24.04 package names (test each `apt_packages` group in the cflinuxfs5 Docker container)
- [ ] Verify/resolve all 🟡 Medium risk items from `docs/cflinuxfs5-investigation.md`:
  - `libdb-dev` → `libdb5.3-dev`
  - `libzookeeper-mt-dev` removal
  - `libcjose-dev` on 24.04
  - `libmcrypt.so` on 24.04
  - `libldap_r.so` symlink removal
  - JRuby JDK URL for noble/jammy
  - OpenSSL 1.1.0g on 24.04 (may need OpenSSL 3.x)
- [ ] Run each recipe against cflinuxfs5 container; fix any remaining issues
- [ ] Update `stacks/cflinuxfs5.yaml` with confirmed values

---

### Phase 7 — Concourse Integration & Cutover (Week 7–8)
**Goal:** Replace the existing Ruby task in the pipeline.

- [ ] Create `buildpacks-ci/tasks/build-binary/build.yml` + `run.sh`
- [ ] Update `pipelines/dependency-builds/pipeline.yml`:
  - Replace `build-binary-new-cflinuxfs4` task references with `build-binary`
  - Add cflinuxfs5 build jobs (same task, different `STACK` param)
- [ ] Update `pipelines/dependency-builds/config.yml`:
  - Add `cflinuxfs5_build_dependencies`, `cflinuxfs5_dependencies`, `cflinuxfs5_buildpacks`
- [ ] Shadow run: run new Go-based task alongside old Ruby task for cflinuxfs4; compare artifact checksums
- [ ] Cutover: remove `build-binary-new-cflinuxfs4/` task once shadow run passes
- [ ] Deprecation: archive `binary-builder/cflinuxfs4/` Ruby code (keep as reference, mark deprecated)

---

## 11. Testing Strategy

### Unit Tests (no Docker required)
- All packages under `internal/` have `_test.go` files
- `FakeRunner` captures all `apt-get`, `make`, `./configure` calls and their arguments
- Stack config loading: assert that cflinuxfs4.yaml and cflinuxfs5.yaml parse correctly
- Compiler setup: assert that `GCC.Setup` calls `add-apt-repository` only when `PPA != ""`; assert correct version numbers passed
- Gfortran CopyLibs: assert correct paths used from stack config
- PHP symlinks: assert cflinuxfs5 does NOT create the `libldap_r` symlink
- Artifact naming: assert SHA256-prefixed filename construction
- Archive: round-trip test (pack → unpack → verify contents)
- PHP extensions: merge logic (base + patch = expected final set)
- Passthrough recipes: assert correct filename templates per dep (e.g. `jprofiler_linux_13_0_14.tar.gz`, `YourKit-JavaProfiler-2024.3.zip`)
- Dotnet prune: assert correct files excluded per variant; assert `RuntimeVersion.txt` injected only for SDK
- Miniconda: assert no file move; assert `out_data.URL` and `out_data.SHA256` set directly

### Integration Tests (requires Docker)
```bash
# Run a single recipe end-to-end inside the target stack container
docker run --rm -v $(pwd):/workspace cloudfoundry/cflinuxfs5 \
  /workspace/bin/binary-builder build \
    --name ruby --version 3.3.6 --sha256 ... \
    --stack cflinuxfs5 \
    --stacks-dir /workspace/stacks \
    --artifacts-dir /tmp/artifacts
```

### Shadow Comparison
Run the Go binary and the Ruby binary against the same input for cflinuxfs4. Compare:
- Artifact SHA256 (should be identical for deterministic builds)
- `builds-artifacts/` JSON content
- `dep-metadata/` JSON content

---

## 12. Migration Path (No Big Bang)

The key safety property: **the old Ruby code keeps working throughout the rewrite.**

```
Week 1-2:  Go scaffold in new binary-builder/cmd/ directory; Ruby code untouched
Week 3-4:  Simple recipes working in Go; Ruby still running in production
Week 5-6:  PHP, R, JRuby working in Go; start shadow-running Go for cflinuxfs4
Week 7:    Shadow confirms parity; cut over cflinuxfs4 to Go
Week 8:    Enable cflinuxfs5 jobs using Go binary; Ruby code archived
```

At no point are both stacks down simultaneously. If the Go binary has a bug for a specific dependency, the Concourse job can be reverted to the Ruby task for that dependency while the bug is fixed.

---

## 13. What This Unlocks

Once the Go rewrite is complete:

| Task | Before (Ruby) | After (Go) |
|------|---------------|------------|
| Add cflinuxfs6 | Copy ~30 files across 2 repos, hunt down stack-specific lines | Add 1 YAML file: `stacks/cflinuxfs6.yaml` |
| Find all Ubuntu-version-specific values | `grep -r` across 2 repos, read all `.rb` files | Open `stacks/cflinuxfs5.yaml` |
| Test a change without Docker | Not possible | `go test ./...` in ~5 seconds |
| Verify gfortran version is correct | Read `builder.rb` lines 216–262 | Read `stacks/cflinuxfs5.yaml` compilers section |
| Add a new recipe | Duplicate a Ruby file, figure out mini_portile | Implement `Recipe` interface, 1 new `.go` file |
| Understand what PHP packages are installed | Read `php_meal.rb` apt_packages method | Read `apt_packages.php_build` in stack YAML |
