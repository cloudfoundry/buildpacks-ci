# cflinuxfs5 Implementation Investigation

**Date:** 2026-02-20  
**Status:** Investigation complete — implementation not yet started  
**Goal:** Add cflinuxfs5 (Ubuntu 24.04 Noble Numbat) support alongside cflinuxfs4 (Ubuntu 22.04 Jammy)

---

## 1. Purpose of `binary-builder/cflinuxfs4/`

`binary-builder/cflinuxfs4/` is a **self-contained, standalone copy** of the root `binary-builder/` directory, forked and modernised for Ubuntu 22.04 (Jammy / cflinuxfs4 stack). The root `binary-builder/` targeted older Ubuntu stacks (cflinuxfs3, Bionic, Trusty) and is now effectively legacy.

Key modernisations in `cflinuxfs4/` vs the root:

| Aspect | Root (`binary-builder/`) | `cflinuxfs4/` |
|--------|--------------------------|---------------|
| Ruby gem | `mini_portile` (custom git fork) | `mini_portile2` (official gem) |
| String literal pragma | `# encoding: utf-8` | `# frozen_string_literal: true` |
| `net-ftp` gem | included | removed |
| PHP apt packages | `libenchant-dev`, no sqlite3, bionic PPA for libtidy | `libenchant-2-dev`, includes sqlite3, no PPA needed |
| PHP libzip | `--with-libzip=/usr/local/lib` | uses system libzip (no flag) |
| PHP Cassandra | copies `libcassandra.so`, `libuv.so` from `/usr/local/lib/` | removed (Cassandra dropped) |
| PHP Imagick | no `ImagickRecipe` class | added `ImagickRecipe` class |
| PHP SNMP | hardcodes `libnetsnmp.so.30` | uses glob `libnetsnmp.so*` |
| PHP Gd 7.x shim | `Gd72and73FakePeclRecipe` present | removed (PHP 7.2/7.3 dropped) |
| Apache httpd | has `update_git` (PPA for newer git) | removed (Jammy ships new enough git) |
| Node | calls python3 directly | checks/installs python3 first |
| JRuby JDK URL | `trusty` in URL | `bionic` in URL |

`cflinuxfs4/` is the **authoritative template** for creating `cflinuxfs5/`.

---

## 2. How the Build Pipeline Uses `binary-builder/cflinuxfs4/`

### Entry point: `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/`

This Concourse task directory drives all binary builds for cflinuxfs4. It:

1. **`build.yml`** — Declares the Concourse task. Hardcodes `repository: cloudfoundry/cflinuxfs4` as the Docker image.
2. **`build.sh`** — Runs inside the Docker container. Installs Ruby 3.4.x from source (stack-agnostic build), then invokes `build.rb`.
3. **`build.rb`** — Entry point Ruby script; invokes `DependencyBuildHelper` from `builder.rb`.
4. **`binary_builder_wrapper.rb`** — Constructs the path to `binary-builder/cflinuxfs4` and shells out to `bin/binary-builder` there.
5. **`builder.rb`** — The main orchestration layer. Contains `setup_ruby`, `setup_gcc`, `build_r_helper`, and all other per-dependency build logic.

### Key hardcoded values in `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/`:

| File | Hardcoded value | Needs change for cflinuxfs5? |
|------|-----------------|------------------------------|
| `build.yml` | `repository: cloudfoundry/cflinuxfs4` | ✅ Yes → `cloudfoundry/cflinuxfs5` |
| `build.yml` | `path: buildpacks-ci/tasks/build-binary-new-cflinuxfs4/build.sh` | ✅ Yes → `…cflinuxfs5/build.sh` |
| `binary_builder_wrapper.rb:4` | `File.join('binary-builder', 'cflinuxfs4')` | ✅ Yes → `'cflinuxfs5'` |
| `builder.rb:141–143` | Ruby binary URL: `ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz` | ✅ Yes → cflinuxfs5-built Ruby binary (see §4) |
| `builder.rb:148` | `Dir.chdir('binary-builder/cflinuxfs4')` | ✅ Yes → `'binary-builder/cflinuxfs5'` |
| `builder.rb:140` comment | mentions "jammy ubuntu repo" | minor — update comment |

---

## 3. Stack-Specific Code in `binary-builder/cflinuxfs4/`

### 3.1 `recipe/php_meal.rb` — apt packages

The `apt_packages` method (lines ~131–171) installs Ubuntu packages. Packages to verify/update for Ubuntu 24.04:

| Package | Status on Ubuntu 24.04 |
|---------|------------------------|
| `libenchant-2-dev` | ✅ Same name on 24.04 |
| `libmagickwand-dev`, `libmagickcore-dev` | ✅ Same name on 24.04 |
| `libdb-dev` | ⚠️ May need `libdb5.3-dev` on 24.04 — needs verification |
| `libzookeeper-mt-dev` | ⚠️ May be dropped from Ubuntu 24.04 universe — needs verification |
| `sqlite3` | ✅ Same name on 24.04 |

### 3.2 `recipe/php_meal.rb` — symlink_commands

The `symlink_commands` method (lines ~189–194):

```ruby
'sudo ln -fs /usr/lib/x86_64-linux-gnu/libldap_r.so /usr/lib/libldap_r.so'
```

⚠️ **`libldap_r` was removed in OpenLDAP 2.6** (present in Ubuntu 22.04 but removed in Ubuntu 24.04). This symlink will fail silently or point to a non-existent file on cflinuxfs5. Needs removal or replacement.

### 3.3 `recipe/php_recipe.rb` — setup_tar

```ruby
cp -a /usr/lib/x86_64-linux-gnu/libmcrypt.so*
```

⚠️ `libmcrypt` availability on Ubuntu 24.04 needs verification. Was available via universe on 22.04 but may have been dropped.

### 3.4 `recipe/python.rb` — Tcl/Tk

```ruby
'--with-tcltk-includes="-I/usr/include/tcl8.6"'
'--with-tcltk-libs="-L/usr/lib/x86_64-linux-gnu -ltcl8.6 ..."'
install_apt('libdb-dev libgdbm-dev tk8.6-dev')
```

✅ Ubuntu 24.04 ships Tcl/Tk 8.6 — these should be fine.  
⚠️ `libdb-dev` same concern as in PHP above.  
⚠️ `--force-yes` flag in `apt-get` is deprecated in newer apt versions (24.04) — should be replaced with `--yes` or `--allow-unauthenticated`.

### 3.5 `recipe/jruby_meal.rb` — JDK URL

```ruby
java_buildpack_java_sdk = 'https://java-buildpack.cloudfoundry.org/openjdk-jdk/bionic/x86_64/openjdk-jdk-1.8.0_242-bionic.tar.gz'
```

⚠️ **Hardcoded `bionic` (Ubuntu 18.04) JDK URL**. For cflinuxfs5, the correct variant (jammy or noble) is needed if this endpoint supports it, or an alternative JDK source should be used.

### 3.6 `recipe/httpd_meal.rb` — libcjose

```ruby
run('apt-get install -y libjansson-dev libcjose-dev libhiredis-dev')
```

⚠️ `libcjose-dev` was available in universe on Ubuntu 22.04 — availability on Ubuntu 24.04 needs verification.

### 3.7 `lib/openssl_replace.rb` — OpenSSL version

Builds **OpenSSL 1.1.0g** (a very old version). Python and Nginx recipes call this. Ubuntu 24.04 ships OpenSSL 3.x natively. Using an ancient 1.1.0g may cause compatibility issues with 24.04 system libraries. Needs investigation — may need updating to a newer OpenSSL version or removal if system OpenSSL is sufficient.

---

## 4. Stack-Specific Code in `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb`

This is the **most critical file** for cflinuxfs5. It contains Ubuntu-version-specific code in several methods.

### 4.1 `setup_ruby` (lines ~139–154)

Downloads a **cflinuxfs4-compiled Ruby binary**:

```ruby
# Updating ruby because bundler 2.6.2+ requires newer ruby than what
# comes from the default jammy ubuntu repo.
download(
  'https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz',
  'ruby.tgz'
)
Dir.chdir('binary-builder/cflinuxfs4') do
  ...
end
```

**For cflinuxfs5:**  
- A `cflinuxfs5`-compiled Ruby binary must exist at the CDN, **OR**  
- The build script can compile Ruby from source (like `build.sh` already does for the task runner itself)  
- `Dir.chdir('binary-builder/cflinuxfs4')` → must become `'binary-builder/cflinuxfs5'`

### 4.2 `build_r_helper` — gfortran (lines ~216–262)

**Ubuntu 22.04 (cflinuxfs4):**
```ruby
Runner.run('apt-get', 'install', '-y', 'gfortran', ..., 'libgfortran-12-dev', ...)
Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-11', './bin/gfortran')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/f951', './bin/f951')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libcaf_single.a', './lib')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libgfortran.a', './lib')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libgfortran.so', './lib')
```

**Must change for cflinuxfs5 (Ubuntu 24.04):**
```ruby
Runner.run('apt-get', 'install', '-y', 'gfortran', ..., 'libgfortran-14-dev', ...)
Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-14', './bin/gfortran')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/14/f951', './bin/f951')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/14/libcaf_single.a', './lib')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/14/libgfortran.a', './lib')
Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/14/libgfortran.so', './lib')
```

### 4.3 `setup_gcc` (lines ~990–997)

Used for Node builds. **Ubuntu 22.04 workaround:**
```ruby
Runner.run('add-apt-repository', '-y', 'ppa:ubuntu-toolchain-r/test')
Runner.run('apt', 'install', '-y', 'gcc-12', 'g++-12')
Runner.run('update-alternatives', ..., '/usr/bin/gcc-12', '60',
           '--slave', ..., '/usr/bin/g++-12')
```

**For cflinuxfs5 (Ubuntu 24.04):**  
Ubuntu 24.04 ships GCC 14 natively — the PPA workaround is likely unnecessary. The `setup_gcc` method should install `gcc-14`/`g++-14` without the PPA, or check if the default GCC version is sufficient.

---

## 5. Files That Are Stack-Agnostic (No Changes Needed)

These files in `cflinuxfs4/` contain no Ubuntu-version-specific code and can be copied verbatim to `cflinuxfs5/`:

- `bin/binary-builder` (shell wrapper)
- `bin/binary-builder.rb` (GoDepMeal entry, dispatcher)
- `bin/download_geoip_db.rb`
- `lib/archive_recipe.rb`
- `lib/geoip_downloader.rb`
- `lib/install_go.rb`
- `lib/utils.rb`
- `lib/yaml_presenter.rb`
- `recipe/base.rb`
- `recipe/bundler.rb`
- `recipe/dep.rb`
- `recipe/determine_checksum.rb`
- `recipe/glide.rb`
- `recipe/godep.rb`
- `recipe/go.rb` (downloads Go bootstrap by SHA — version may need updating but is not stack-specific)
- `recipe/hwc.rb` (`mingw-w64` same on 24.04)
- `recipe/jruby.rb`
- `recipe/maven.rb`
- `recipe/nginx.rb` (calls `openssl_replace` — see §3.7 concern)
- `recipe/ruby.rb`
- `Gemfile` (uses `mini_portile2`, `ruby ~> 3.4` — no stack-specific versions)

Similarly in `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/`:
- `build.sh` — installs Ruby from source, stack-agnostic
- `build.rb` — thin entry point, no stack references
- `build_input.rb`, `build_output.rb`, `artifact_output.rb`, `source_input.rb`, `dep_metadata_output.rb` — pure data classes, no stack references
- `php_extensions/` directory — extension definitions, may need minor updates for PHP on 24.04 but are not inherently stack-specific Ruby code

---

## 6. Implementation Plan for cflinuxfs5

### Step 1: Create `binary-builder/cflinuxfs5/`

Copy `binary-builder/cflinuxfs4/` in full, then apply these targeted changes:

#### `recipe/php_meal.rb`
- [ ] Verify/replace `libdb-dev` → check Ubuntu 24.04 package name
- [ ] Verify/remove `libzookeeper-mt-dev` → check if available on 24.04
- [ ] Remove `libldap_r.so` symlink from `symlink_commands` (dropped in OpenLDAP 2.6)

#### `recipe/php_recipe.rb`
- [ ] Verify `libmcrypt.so` availability on Ubuntu 24.04

#### `recipe/python.rb`
- [ ] Replace `--force-yes` with `--yes` in apt-get call

#### `recipe/jruby_meal.rb`
- [ ] Update JDK URL from `bionic` to appropriate `jammy` or `noble` variant

#### `recipe/httpd_meal.rb`
- [ ] Verify `libcjose-dev` availability on Ubuntu 24.04

#### `lib/openssl_replace.rb`
- [ ] Investigate whether OpenSSL 1.1.0g builds/works on Ubuntu 24.04; consider upgrading

### Step 2: Create `buildpacks-ci/tasks/build-binary-new-cflinuxfs5/`

Copy `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/` in full, then apply:

#### `build.yml`
- [ ] `repository: cloudfoundry/cflinuxfs4` → `cloudfoundry/cflinuxfs5`
- [ ] `path: .../build-binary-new-cflinuxfs4/build.sh` → `.../build-binary-new-cflinuxfs5/build.sh`

#### `binary_builder_wrapper.rb`
- [ ] `File.join('binary-builder', 'cflinuxfs4')` → `File.join('binary-builder', 'cflinuxfs5')`

#### `builder.rb`
- [ ] `setup_ruby`: Update Ruby binary URL to cflinuxfs5-built binary (once available), or compile from source
- [ ] `setup_ruby`: `Dir.chdir('binary-builder/cflinuxfs4')` → `'binary-builder/cflinuxfs5'`
- [ ] `build_r_helper`: `gfortran-11`/`libgfortran-12-dev`/paths with `11/` → `gfortran-14`/`libgfortran-14-dev`/paths with `14/`
- [ ] `setup_gcc`: Replace GCC 12 + PPA with GCC 14 (native on 24.04, no PPA needed)

### Step 3: Update `pipelines/dependency-builds/`

- [ ] `config.yml`: Add `cflinuxfs5_build_dependencies`, `cflinuxfs5_dependencies`, `cflinuxfs5_buildpacks` lists
- [ ] `pipeline.yml`: Add cflinuxfs5 build jobs using `tasks/build-binary-new-cflinuxfs5/`

### Step 4: Update buildpack `*-values.yml` files

Add `cflinuxfs5` to the `stacks:` list in each buildpack values file:
- `python-values.yml`, `ruby-values.yml`, `go-values.yml`, `nodejs-values.yml`
- `php-values.yml`, `java-values.yml`, `dotnet-core-values.yml`, `nginx-values.yml`
- `r-values.yml`, `staticfile-values.yml`, `apt-values.yml`, `binary-values.yml`

### Step 5: Update `pipelines/buildpack/pipeline.yml`

- [ ] Add `version-stack-cflinuxfs5` semver resource (bucket: `cflinuxfs5-release`)
- [ ] Integration test jobs: conditionally get cflinuxfs5 version resource

---

## 7. Open Questions / Risks

| Question | Risk level | Notes |
|----------|------------|-------|
| `setup_ruby`: cflinuxfs5-built Ruby binary URL | 🔴 High | Binary must be pre-built and uploaded to CDN before task works; alternatively compile from source like `build.sh` does |
| `libdb-dev` on Ubuntu 24.04 | 🟡 Medium | Used by PHP and Python; package may be renamed |
| `libzookeeper-mt-dev` on Ubuntu 24.04 | 🟡 Medium | Used by PHP; may be dropped from 24.04 universe |
| `libcjose-dev` on Ubuntu 24.04 | 🟡 Medium | Used by Apache httpd; was in universe on 22.04 |
| `libmcrypt.so` on Ubuntu 24.04 | 🟡 Medium | Used by PHP; libmcrypt availability needs checking |
| OpenSSL 1.1.0g on Ubuntu 24.04 | 🟡 Medium | Very old version; may conflict with 24.04 system OpenSSL 3.x |
| JRuby JDK `bionic` URL | 🟡 Medium | Needs a `noble` or `jammy` variant from java-buildpack CDN |
| `libldap_r.so` symlink | 🟢 Low | Known removed in OpenLDAP 2.6; just needs removing from symlink_commands |
| `--force-yes` in apt-get (python.rb) | 🟢 Low | Deprecated but usually harmless; easy to fix |
| GCC 14 for Node builds | 🟢 Low | Ubuntu 24.04 ships GCC 14 natively; PPA approach not needed |

---

## 8. Approach Rationale

The **per-stack task directory approach** was chosen over the previously attempted stack-agnostic `tasks/build-binary-stack/` approach because:

- `builder.rb` installs Ubuntu-version-specific apt packages (different gfortran versions, different GCC PPAs, different library names)
- Trying to branch on `STACK` env var inside a shared script creates implicit coupling and makes the stack-specific differences harder to track and review
- Separate directories (`build-binary-new-cflinuxfs4/` and `build-binary-new-cflinuxfs5/`) make the differences explicit, reviewable as a diff, and independently deployable
- Same rationale applies to `binary-builder/cflinuxfs4/` vs `binary-builder/cflinuxfs5/`
