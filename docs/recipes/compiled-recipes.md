# Compiled Recipes

This document is the authoritative spec for all deps that require compilation — autoconf/make builds, custom compile steps, binary_builder delegates, and git-clone builds.

Reference: `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` and `binary-builder/cflinuxfs4/recipe/`

---

## Recipe inventory

| Dep name | Build mechanism | Stack-specific | Key stack values used |
|----------|----------------|----------------|-----------------------|
| `ruby` | portile (binary_builder) | ✅ | `ruby_build` apt, ruby bootstrap |
| `bundler` | setup_ruby + gem install | ✅ | ruby bootstrap URL from stack |
| `python` | portile + tcl/tk debs | ✅ | `python_build` apt, `use_force_yes`, `tcl_version` |
| `node` | portile + gcc setup | ✅ | `node_build` apt, `gcc` compiler config |
| `go` | bootstrap + make.bash | ✅ | (no stack apt; uses system Go) |
| `nginx` | configure/make + GPG | ✅ | (no stack apt; openssl replace) |
| `nginx-static` | configure/make + GPG | ✅ | (same as nginx, PIE flags) |
| `openresty` | configure/make | ✅ | (no GPG, no stack apt) |
| `httpd` | portile × 5 | ✅ | `httpd_build` apt |
| `jruby` | JDK + Maven + source | ✅ | `jruby` config block in stack |
| `r` | configure/make + R pkgs | ✅ | `r_build` apt, `gfortran` compiler config |
| `libunwind` | configure/make | ✅ | (no stack apt) |
| `libgdiplus` | git clone + autogen | ✅ | `libgdiplus_build` apt |
| `dep` | binary_builder | ✅ | (no stack apt) |
| `glide` | binary_builder | ✅ | (no stack apt) |
| `godep` | binary_builder | ✅ | (no stack apt) |
| `hwc` | cross-compile (mingw-w64) | ❌ | (Windows binary, any-stack) |

---

## ruby

**Ruby method:** `build_ruby` → delegates to `@binary_builder.build(@source_input)`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `binary_builder.build(source_input)` — inside `binary-builder/cflinuxfs4/`:
   - apt install `libffi-dev` (from `ruby_build` apt list in stack config)
   - Downloads Ruby source from `cache.ruby-lang.org`
   - Runs portile: `./configure --enable-load-relative --disable-install-doc --without-gmp`
   - Installs to `/app/vendor/ruby-{version}`
2. `archive.StripIncorrectWordsYAML(filepath)` — removes `incorrect_words.yaml` from tar and nested jars

### Go implementation notes
- Artifact prefix: `ruby_{version}_linux_x64_{stack}`
- Post-processing: `StripIncorrectWordsYAML` must run before `merge_out_data`
- The `--without-gmp` flag is intentional — reduces binary size

---

## bundler

**Ruby method:** `build_bundler`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. `DependencyBuildHelper.setup_ruby`:
   - Downloads pre-built Ruby binary from `stack.RubyBootstrap.URL` (stack-specific)
   - Extracts to `/opt/ruby`
   - Prepends `/opt/ruby/bin` to `PATH`
   - Runs `bundle install` inside `binary-builder/{stack}`
2. `binary_builder.build(source_input)` — inside `binary-builder/cflinuxfs4/`:
   - `gem install bundler -v {version} --no-document`
   - Rewrites shebangs in installed gems

### Go implementation notes
- `setup_ruby` is stack-specific: URL and install path come from `stack.RubyBootstrap`
- Artifact prefix: `bundler_{version}_linux_noarch_{stack}`
- The Go binary itself replaces the `binary-builder/cflinuxfs4/` delegate — no separate process needed

---

## python

**Ruby method:** `build_python`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. In a temp dir, extracts `source/Python-{version}.tgz` (or downloads if not present)
2. `./configure --enable-shared --with-ensurepip=yes --with-dbmliborder=bdb:gdbm --with-tcltk-includes="-I/usr/include/tcl8.6" --with-tcltk-libs="..." --enable-unicode=ucs4`
3. apt install `libdb-dev libgdbm-dev tk8.6-dev` (from `python_build` in stack config; `libdb-dev` → `libdb5.3-dev` on cflinuxfs5)
4. `apt-get -y [--force-yes|-y] -d install --reinstall libtcl8.6 libtk8.6 libxss1` — downloads .deb files to apt cache without installing
5. `dpkg -x {path}.deb {destdir}` for each of: `libtcl8.6`, `libtk8.6`, `libxss1` — extracts .deb contents into prefix so they are bundled in the artifact
6. `make && make install`
7. Creates `bin/python` symlink → `python3`
8. `tar zcvf ... --hard-dereference` — packs with hard-dereference to resolve symlinks

### Go implementation notes
- `use_force_yes` from stack config controls whether to pass `--force-yes` to apt (cflinuxfs4: true; cflinuxfs5: false)
- tcl/tk version `8.6` from `stack.Python.TCLVersion`
- **Bug fixes applied:** See `known-bugs.md` bugs #2, #4, #5
- Artifact prefix: `python_{version}_linux_x64_{stack}`

---

## node

**Ruby method:** `build_node`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `Utils.setup_python_and_pip` — apt install python3 + pip3
2. `Utils.setup_gcc`:
   - apt install `software-properties-common`
   - If `stack.Compilers.GCC.PPA != ""`: `add-apt-repository -y {ppa}` (cflinuxfs4 only)
   - apt install `gcc-{version}` `g++-{version}` (version from stack config)
   - `update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-{version} 60 --slave /usr/bin/g++ g++ /usr/bin/g++-{version}`
3. Strips `v` prefix from version: `"v22.14.0"` → `"22.14.0"`
4. `binary_builder.build(source_input)` — inside `binary-builder/cflinuxfs4/`:
   - Downloads Node source, configures, compiles
5. `archive.StripTopLevelDir(filepath)`

### Go implementation notes
- PPA is conditional: `if s.Compilers.GCC.PPA != ""` — cflinuxfs5 skips the PPA entirely
- Version stripping: `strings.TrimPrefix(src.Version, "v")`
- Artifact prefix: `node_{version}_linux_x64_{stack}`

---

## go

**Ruby method:** `build_go`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. Strips `go` prefix from version: `"go1.24.2"` → `"1.24.2"`
2. `binary_builder.build(source_input)` — inside `binary-builder/cflinuxfs4/`:
   - Downloads Go bootstrap (go1.24.2 binary from go.dev)
   - Runs `make.bash` to compile Go from source
   - Produces `go{version}.linux-amd64.tar.gz`
3. `archive.StripTopLevelDir(filepath)` — removes top-level `go/` directory

### Go implementation notes
- Version stripping: `strings.TrimPrefix(src.Version, "go")`
- The bootstrap Go version is pinned in `binary-builder/cflinuxfs4/lib/install_go.rb` — the Go recipe must use a similar bootstrap mechanism
- Artifact prefix: `go_{version}_linux_x64_{stack}`

---

## nginx

**Ruby method:** `build_nginx`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. GPG verification of the nginx tarball + `.asc` signature using 6 nginx public keys
2. Downloads source, extracts
3. `./configure` with base options + PIC flags:
   - `--with-cc-opt=-fPIC -pie`
   - `--with-ld-opt=-fPIC -pie -z now`
   - `--with-compat --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-http_sub_module`
   - Plus all standard nginx options (ssl, v2, realip, gunzip, gzip_static, auth_request, random_index, secure_link, stub_status; without uwsgi, scgi)
4. `make && make install DESTDIR={destdir}/nginx`
5. Removes `html/` and `conf/` from install, creates empty `conf/`
6. Tars the entire `destdir` (includes surrounding directory)
7. `archive.StripTopLevelDir` — removes top-level directory

### nginx-static differences
- Uses PIE flags instead of PIC: `--with-cc-opt=-fPIE -pie`, `--with-ld-opt=-fPIE -pie -z now`
- No `--with-compat --with-mail --with-stream --with-http_sub_module` options
- Tar uses only `nginx` subdirectory (no surrounding dir), so no strip needed but strip is still called

### GPG keys (both nginx and nginx-static)
```go
var nginxGPGKeys = []string{
    "http://nginx.org/keys/maxim.key",     // Maxim Konovalov
    "http://nginx.org/keys/arut.key",      // Roman Arutyunyan
    "https://nginx.org/keys/pluknet.key",  // Sergey Kandaurov
    "http://nginx.org/keys/sb.key",        // Sergey Budnevitch
    "http://nginx.org/keys/thresh.key",    // Konstantin Pavlov
    "https://nginx.org/keys/nginx_signing.key", // nginx release key
}
```

### Go implementation notes
- `internal/gpg` package handles the verify logic
- Artifact prefix: `nginx_{version}_linux_x64_{stack}`
- Artifact prefix (static): `nginx-static_{version}_linux_x64_{stack}`

---

## openresty

**Ruby method:** `build_openresty`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `wget {url}` — no GPG verification (TODO comment in original code)
2. `./configure` with same base options as nginx + PIC flags + `-j2`
3. `make -j2 && make install`
4. Removes `nginx/html`, `nginx/conf`, creates `nginx/conf`, removes `bin/openresty`
5. Tars from inside the openresty install dir

### Go implementation notes
- No GPG — this is a known gap, carried forward as a TODO
- Artifact prefix: `openresty_{version}_linux_x64_{stack}`

---

## httpd (Apache HTTPD)

**Ruby method:** `build_httpd` → delegates to `@binary_builder.build(@source_input)`  
**Artifact arch:** `linux_x64_{stack}`

### What it does (inside `binary-builder/cflinuxfs4/recipe/httpd_meal.rb`)
1. apt install from `httpd_build` apt list in stack config: `libldap2-dev libjansson-dev libcjose-dev libhiredis-dev`
2. Builds APR (Apache Portable Runtime) via portile — fetches latest from GitHub
3. Builds APR-Iconv via portile
4. Builds APR-Util via portile (depends on APR)
5. Builds HTTPD via portile (depends on APR, APR-Iconv, APR-Util)
6. Builds mod_auth_openidc via portile
7. `archive.StripTopLevelDir`

### Go implementation notes
- `libcjose-dev` is in `httpd_build` for cflinuxfs4 but marked uncertain for cflinuxfs5 — presence in stack config YAML controls installation
- APR version is discovered dynamically from GitHub API: `https://api.github.com/repos/apache/apr/releases/latest`
- Artifact prefix: `httpd_{version}_linux_x64_{stack}`

---

## jruby

**Ruby method:** `build_jruby`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. Determines ruby version from jruby version:
   - `9.3.x.x` → ruby `2.6`
   - `9.4.x.x` → ruby `3.1`
   - Other → error
2. Augments version: `full_version = "{jruby_version}-ruby-{ruby_version}"`
3. Downloads JDK from `stack.JRuby.JDKURL` to `stack.JRuby.JDKInstallDir`
4. Builds JRuby via Maven + source compile
5. `archive.StripIncorrectWordsYAML(filepath)` — removes `incorrect_words.yaml` from jar files
6. Artifact filename uses `full_version`: `jruby_{full_version}_linux_x64_{stack}`

### Stack config fields used
```yaml
jruby:
  jdk_url: https://java-buildpack.cloudfoundry.org/openjdk-jdk/bionic/x86_64/openjdk-jdk-1.8.0_242-bionic.tar.gz
  jdk_sha256: dcb9fea...
  jdk_install_dir: /opt/java
```

### Go implementation notes
- JDK URL is **entirely stack-driven** — cflinuxfs4 uses `bionic`, cflinuxfs5 must use `jammy` or `noble`
- The `9.3`/`9.4` → ruby version mapping is hardcoded logic (not stack config) — this is JRuby's own versioning scheme
- Artifact prefix: `jruby_{full_version}_linux_x64_{stack}`

---

## r

**Ruby method:** `build_r`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Reads 4 sub-dependency source inputs from Concourse resource dirs:
   - `source-forecast-latest/data.json`
   - `source-plumber-latest/data.json`
   - `source-rserve-latest/data.json`
   - `source-shiny-latest/data.json`
2. `apt install` from `r_build` apt list (stack-specific packages, gfortran version)
3. Downloads R source, `./configure --with-readline=no --with-x=no --enable-R-shlib`
4. `make && make install`
5. `R --vanilla -e "install.packages('devtools', ...)"` — installs devtools
6. Installs 4 R packages via `devtools::install_version`:
   - `Rserve` (version from rserve sub-dep; dots+dashes in version formatting)
   - `forecast`
   - `shiny`
   - `plumber`
7. Removes devtools: `R --vanilla -e 'remove.packages("devtools")'`
8. Copies gfortran libs into R install (from `stack.Compilers.Gfortran.LibPath`):
   - `{gfortran_bin}` → `./bin/gfortran`
   - `{lib_path}/f951` → `./bin/f951`
   - Creates `./bin/f95` symlink → `./gfortran`
   - `{lib_path}/libcaf_single.a` → `./lib`
   - `{lib_path}/libgfortran.a` → `./lib`
   - `{lib_path}/libgfortran.so` → `./lib`
   - `/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0` → `./lib`
9. `tar zcvf r-v{version}.tgz .` from inside `/usr/local/lib/R`

### Rserve version formatting
```ruby
rserve_version = "#{rserve_input.split('.')[0..1].join('.')}-#{rserve_input.split('.')[2..].join('.')}"
# "1.8.14" → "1.8-14"  (first two parts joined by dot, rest joined by dash)
```

### Sub-dependencies in out_data
```go
outData.SubDependencies = map[string]SubDep{
    "forecast": {Source: {URL: ..., SHA256: ...}, Version: ...},
    "plumber":  {Source: {URL: ..., SHA256: ...}, Version: ...},
    "rserve":   {Source: {URL: ..., SHA256: ...}, Version: ...},
    "shiny":    {Source: {URL: ..., SHA256: ...}, Version: ...},
}
```

### Go implementation notes
- The 4 sub-dep source files are read from specific dirs — the CLI/task must pass these dirs or the recipe reads them from well-known relative paths
- All gfortran paths come from `stack.Compilers.Gfortran` — no hardcoded paths in Go code
- `git_commit_sha` in out_data is set to the SHA256 of the downloaded R source tarball
- Artifact prefix: `r_{version}_linux_noarch_{stack}`

---

## libunwind

**Ruby method:** `build_libunwind`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. The github-releases depwatcher has already downloaded the `.tar.gz` into `source/`
2. Extracts filename from URL, strips `.tar.gz` suffix to get dir name
3. Extracts tarball in `source/`
4. `./configure --prefix={built_path}`
5. `make && make install`
6. `tar czf {dir}.tgz include lib` — packs only `include/` and `lib/`

### Go implementation notes
- Source tarball is pre-downloaded by Concourse — no download step
- Artifact prefix: `libunwind_{version}_linux_noarch_{stack}`

---

## libgdiplus

**Ruby method:** `build_libgdiplus`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. apt install from `libgdiplus_build` apt list: `automake libtool libglib2.0-dev libcairo2-dev`
2. `git clone --single-branch --branch {version} https://github.com/{repo} libgdiplus-{version}`
3. Sets env: `CXXFLAGS="-g -Wno-maybe-uninitialized"` and `CFLAGS="-g -Wno-maybe-uninitialized"`
4. `./autogen.sh --prefix={built_path}`
5. `make && make install`
6. `tar czf libgdiplus-{version}.tgz lib` — packs only `lib/`

### Go implementation notes
- Uses `source_input.Repo` (e.g. `mono/libgdiplus`) for the GitHub URL
- Uses `source_input.Version` as the git branch/tag
- Env vars set via `RunWithEnv`
- Artifact prefix: `libgdiplus_{version}_linux_noarch_{stack}`

---

## dep, glide, godep

**Ruby methods:** `build_dep`, `build_glide`, `build_godep`  
**Artifact arch:** `linux_x64_{stack}`

### What each does
All three delegate to `@binary_builder.build(@source_input)` inside `binary-builder/cflinuxfs4/`.

- **dep**: Output: `dep-v{version}-linux-x64.tgz`
- **glide**: Output: `glide-v{version}-linux-x64.tgz`
- **godep**: Output: `godep-v{version}-linux-x64.tgz`

### Go implementation notes
- All three are Go tool builds — download source, `go build`, tar the binary
- Artifact prefixes: `dep_{version}_linux_x64_{stack}`, `glide_{version}_linux_x64_{stack}`, `godep_{version}_linux_x64_{stack}`

---

## hwc (Hostable Web Core)

**Ruby method:** `build_hwc`  
**Artifact arch:** `windows_x86-64_any-stack`

### What it does
- Delegates to `@binary_builder.build(@source_input)` inside `binary-builder/cflinuxfs4/`
- Cross-compiles for Windows using `mingw-w64`
- Produces a `.zip` file: `hwc-{version}-windows-x86-64.zip`

### Go implementation notes
- `mingw-w64` is the same package on Ubuntu 22.04 and 24.04 — no stack config needed
- Artifact prefix: `hwc_{version}_windows_x86-64_any-stack`
- Output is a `.zip`, not a `.tgz`
