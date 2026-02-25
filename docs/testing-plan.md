# Testing Plan: Go binary-builder rewrite + cflinuxfs5 parity

**Status:** Approved — implementation not yet started  
**Scope:** All four test tiers for the Go rewrite of `binary-builder`, covering unit correctness,
build parity against the Ruby builder, binary exerciser validation, and Concourse shadow-run
verification before production cutover.

**Related documents:**
- [`docs/cflinuxfs5-go-rewrite-plan.md`](cflinuxfs5-go-rewrite-plan.md) — master implementation plan
- [`docs/cflinuxfs5-investigation.md`](cflinuxfs5-investigation.md) — stack-specific code findings
- [`docs/recipes/compiled-recipes.md`](recipes/compiled-recipes.md) — compiled recipe specs
- [`docs/recipes/passthrough-recipes.md`](recipes/passthrough-recipes.md) — passthrough recipe specs
- [`docs/recipes/php-recipe.md`](recipes/php-recipe.md) — PHP recipe spec
- [`docs/recipes/known-bugs.md`](recipes/known-bugs.md) — bugs fixed in the Go rewrite

---

## Overview

Four tiers, each with a distinct purpose and runtime environment:

| Tier | Name | Requires Docker | Requires Network | When it runs |
|------|------|-----------------|------------------|--------------|
| 1 | Go Unit Tests | No | No | Every PR, every commit |
| 2 | Build Parity Tests | Yes (cflinuxfs4) | Yes (downloads) | Nightly + pre-cutover |
| 3 | Exerciser Tests | Yes (target stack) | No (uses built artifact) | Nightly + pre-cutover |
| 4 | Concourse Shadow Run | Yes (CI) | Yes (CI) | Shadow pipeline only |

Tiers 1 and 3 are the primary day-to-day quality gates.  
Tier 2 is the parity gate that must pass before the Go builder replaces the Ruby builder for cflinuxfs4.  
Tier 4 is the production gate before full cutover.

---

## Tier 1 — Go Unit Tests

**Goal:** Verify every internal package in isolation. No Docker, no network, no filesystem side
effects. Runs in < 10 seconds on any developer machine.

**Location:** `binary-builder/internal/*/..._test.go`

**Runner:** `go test ./...` from the `binary-builder/` root.

### 1.1 FakeRunner

All packages that shell out accept a `runner.Runner` interface. Tests inject `FakeRunner`, which
records every call without executing anything.

```go
// internal/runner/runner.go
type Call struct {
    Name string
    Args []string
    Env  map[string]string
    Dir  string
}

type FakeRunner struct {
    Calls       []Call
    OutputMap   map[string]string // keyed by "name args..." → stdout
    ErrorMap    map[string]error  // keyed by "name args..." → error to return
}
```

Assertions use `FakeRunner.Calls` to verify the exact sequence, arguments, and environment of
every `apt-get`, `make`, `./configure`, `git`, `gpg`, `wget`, `cp`, `ln` call.

### 1.2 Per-package assertions

#### `internal/stack`

| Test | Assertion |
|------|-----------|
| Load cflinuxfs4.yaml | All fields parse without error; `Stack.Name == "cflinuxfs4"` |
| Load cflinuxfs5.yaml | All fields parse without error; `Stack.Name == "cflinuxfs5"` |
| Gfortran version cflinuxfs4 | `Stack.Compilers.Gfortran.Version == 11` |
| Gfortran version cflinuxfs5 | `Stack.Compilers.Gfortran.Version == 14` |
| GCC PPA cflinuxfs4 | `Stack.Compilers.GCC.PPA == "ppa:ubuntu-toolchain-r/test"` |
| GCC PPA cflinuxfs5 | `Stack.Compilers.GCC.PPA == ""` |
| PHP symlinks cflinuxfs4 | Symlink list contains entry with `dst == "/usr/lib/libldap_r.so"` |
| PHP symlinks cflinuxfs5 | Symlink list does NOT contain any entry with `dst == "/usr/lib/libldap_r.so"` |
| python.use_force_yes cflinuxfs4 | `true` |
| python.use_force_yes cflinuxfs5 | `false` |
| php_build packages cflinuxfs4 | Contains `"libdb-dev"`, does NOT contain `"libdb5.3-dev"` |
| php_build packages cflinuxfs5 | Contains `"libdb5.3-dev"`, does NOT contain `"libdb-dev"` |
| php_build packages cflinuxfs4 | Contains `"libzookeeper-mt-dev"` |
| php_build packages cflinuxfs5 | Does NOT contain `"libzookeeper-mt-dev"` |
| r_build packages cflinuxfs4 | Contains `"libpcre++-dev"` and `"libtiff5-dev"` |
| r_build packages cflinuxfs5 | Does NOT contain `"libpcre++-dev"`; contains `"libtiff-dev"` not `"libtiff5-dev"` |
| Load missing file | Returns descriptive error |
| Load unknown stack name | Returns error |

#### `internal/runner`

| Test | Assertion |
|------|-----------|
| RealRunner.Run success | Returns nil; command executed |
| RealRunner.Run failure | Returns error containing command name |
| FakeRunner records calls | `Calls[0].Name == "apt-get"`, `Calls[0].Args == ["-y", "install", "foo"]` |
| FakeRunner.Output returns configured value | Returns `OutputMap["git describe"]` |
| FakeRunner.ErrorMap triggers error | Returns configured error for matching call |

#### `internal/apt`

| Test | Assertion |
|------|-----------|
| Install packages | FakeRunner sees `apt-get -y install pkg1 pkg2` |
| Update | FakeRunner sees `apt-get update` |
| AddPPA (non-empty) | FakeRunner sees `add-apt-repository -y ppa:...` then `apt-get update` |
| AddPPA (empty string) | FakeRunner sees NO `add-apt-repository` call |
| InstallReinstall with use_force_yes=true | FakeRunner sees `apt-get --force-yes -d install --reinstall ...` |
| InstallReinstall with use_force_yes=false | FakeRunner sees `apt-get --yes -d install --reinstall ...`; NO `--force-yes` |

#### `internal/compiler`

| Test | Assertion |
|------|-----------|
| GCC.Setup cflinuxfs4 | FakeRunner sees `add-apt-repository` for PPA, then `apt-get install gcc-12 g++-12`, then `update-alternatives` calls |
| GCC.Setup cflinuxfs5 | FakeRunner sees NO `add-apt-repository`; sees `apt-get install gcc-14 g++-14` |
| Gfortran.Setup cflinuxfs4 | FakeRunner sees `apt-get install gfortran libgfortran-12-dev` |
| Gfortran.Setup cflinuxfs5 | FakeRunner sees `apt-get install gfortran libgfortran-14-dev` |
| Gfortran.CopyLibs cflinuxfs4 | FakeRunner sees `cp` from `/usr/lib/gcc/x86_64-linux-gnu/11/...` |
| Gfortran.CopyLibs cflinuxfs5 | FakeRunner sees `cp` from `/usr/lib/gcc/x86_64-linux-gnu/14/...` |

#### `internal/fetch`

| Test | Assertion |
|------|-----------|
| Download correct SHA256 | File written; no error |
| Download wrong SHA256 | Returns error containing "SHA256 digest does not match" |
| Download wrong SHA512 | Returns error containing "SHA512 digest does not match" |
| Download wrong MD5 | Returns error |
| Download follows redirect | Final URL fetched; checksum verified against final body |
| Download 404 | Returns error containing status code |
| ReadBody success | Returns body bytes |

#### `internal/gpg`

| Test | Assertion |
|------|-----------|
| VerifySignature | FakeRunner sees `wget` for each key URL, `gpg --import` for each, `wget` for file + sig, `gpg --verify sig file` |
| Multiple key URLs | All keys imported before verify |

#### `internal/source`

| Test | Assertion |
|------|-----------|
| Parse modern format (with `source`/`version` keys) | All fields populated correctly |
| Parse legacy format (with `name`/`source_uri`/`version`/`source_sha` keys) | All fields populated correctly |
| PrimaryChecksum prefers SHA512 over SHA256 | Returns SHA512 checksum |
| PrimaryChecksum falls back to SHA256 | Returns SHA256 when no SHA512 |
| PrimaryChecksum falls back to MD5 | Returns MD5 when no SHA |
| Missing file | Returns error |
| Malformed JSON | Returns error |

#### `internal/archive`

| Test | Assertion |
|------|-----------|
| Pack creates tarball | Tarball exists; `tar -tzf` lists expected files |
| StripTopLevelDir | Re-archived tarball has no top-level directory prefix |
| StripFiles removes matching pattern | Files matching pattern absent from re-archived tarball |
| StripIncorrectWordsYAML | `incorrect_words.yaml` absent from tarball and from nested jars |
| PackZip creates zip | Zip exists; `unzip -l` lists expected files |

#### `internal/artifact`

| Test | Assertion |
|------|-----------|
| Filename for linux dep | `ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz` |
| Filename for windows dep | `hwc_2.0.0_windows_x86-64_any-stack_abcd1234.zip` |
| Filename for noarch dep | `bundler_2.5.0_linux_noarch_cflinuxfs4_abcd1234.tgz` |
| S3URL | `https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_...tgz` |
| S3URL with `+` in version | `openjdk_11.0.22%2B7_linux_x64_cflinuxfs4_...tgz` — `+` encoded as `%2B` (PR #553) |
| SHA256 prefix is first 8 chars | `sha256[0:8]` appears in filename |

#### `internal/portile`

| Test | Assertion |
|------|-----------|
| TmpPath | Returns `/tmp/{arch}/ports/{name}/{version}` |
| Cook sequence | FakeRunner sees: download, extract, `./configure --prefix=...`, `make`, `make install` in order |
| Cook with extra options | Extra options appended to `./configure` call |
| Cook failure on make | Returns error; subsequent steps not called |

#### `internal/php`

| Test | Assertion |
|------|-----------|
| Load base extensions | NativeModules and Extensions populated from base YAML |
| Apply patch (add extension) | Extension present in merged set |
| Apply patch (remove extension) | Extension absent from merged set |
| Apply patch (update version) | Extension has patched version |
| RecipeFor known klass | Returns correct recipe builder |
| RecipeFor unknown klass | Returns descriptive error |

#### Recipe-level unit tests (using FakeRunner)

| Recipe | Key assertions |
|--------|---------------|
| `bundler` | FakeRunner sees `setup_ruby` sequence (mkdir, curl, tar, PATH update), then `gem install bundler`, then shebang replacement |
| `python` | FakeRunner sees `apt-get install libdb-dev` (cflinuxfs4) or `libdb5.3-dev` (cflinuxfs5); sees `apt-get --force-yes` (cflinuxfs4) or `apt-get --yes` (cflinuxfs5) for tcl/tk reinstall |
| `node` | FakeRunner sees GCC PPA add (cflinuxfs4) or no PPA (cflinuxfs5) |
| `r` | FakeRunner sees `cp` from gfortran-11 paths (cflinuxfs4) or gfortran-14 paths (cflinuxfs5) |
| `php` | FakeRunner sees `apt-get install` with cflinuxfs4 package list; symlink calls include `libldap_r` |
| `php` (cflinuxfs5) | Symlink calls do NOT include `libldap_r` |
| `your_kit_profiler` | Dispatch succeeds (bug fix: `strings.ReplaceAll` not `.sub`) |
| `miniconda` | No file move; `out_data.URL` and `out_data.SHA256` set directly from source input |
| `nginx` | FakeRunner sees GPG verify sequence before configure |
| `jruby` | FakeRunner sees JDK download from `stack.JRuby.JDKURL` (bionic URL for cflinuxfs4, noble URL for cflinuxfs5) |

---

## Tier 2 — Build Parity Tests

**Goal:** Prove that the Go builder produces outputs that are semantically equivalent to the Ruby
builder for cflinuxfs4. This is the gate before cutover.

**Location:** `binary-builder/test/parity/`

**Runner:** `make parity-test DEP=ruby VERSION=3.3.6 SHA256=...` — runs inside cflinuxfs4 Docker.

### 2.1 What is compared

For each dependency build, both builders are invoked with identical inputs. The following outputs
are compared:

#### A. Artifact file

| Check | Pass condition |
|-------|---------------|
| File exists | Both sides produce a file |
| Filename pattern | Both filenames match the same regex (name, version, os, arch, stack, 8-char sha prefix, extension) |
| SHA256 of artifact | **Must match** for passthrough/repack deps (see determinism table §2.3) |
| Tar file list | `tar -tzf` output, sorted, must be identical |

#### B. `builds-artifacts/binary-builds-new/{name}/{version}-cflinuxfs4.json`

Both JSON files are parsed and compared field by field:

| Field | Pass condition |
|-------|---------------|
| `version` | Identical string |
| `source.url` | Identical string |
| `source.sha256` | Identical string (or both absent) |
| `source.sha512` | Identical string (or both absent) |
| `source.md5` | Identical string (or both absent) |
| `source.sha1` | Identical string (or both absent) |
| `url` | Identical string (the artifact S3 URL) |
| `sha256` | Identical string (the artifact SHA256) |
| `sub_dependencies` | All keys present in both; versions identical |
| `git_commit_sha` | Identical string (or both absent) |

#### C. `dep-metadata/{artifact}_metadata.json`

Same field-by-field comparison as B (it contains the same `out_data` hash).

#### D. Binary self-report (inside Docker)

After extracting the artifact, run the binary and assert the version string. See §3 for the
per-dep exerciser commands.

### 2.2 Parity test script

```bash
#!/usr/bin/env bash
# binary-builder/test/parity/compare-builds.sh
# Usage: compare-builds.sh <dep-name> <version> <sha256> [<stack>]
#
# Runs both the Ruby builder and the Go builder inside the target stack Docker
# container, then diffs every observable output. Exits 1 on any mismatch.

set -euo pipefail

DEP="${1:?dep name required}"
VERSION="${2:?version required}"
SHA256="${3:?sha256 required}"
STACK="${4:-cflinuxfs4}"
IMAGE="cloudfoundry/${STACK}"

RUBY_OUT="$(mktemp -d)"
GO_OUT="$(mktemp -d)"

run_ruby_builder() {
  docker run --rm \
    -v "$(pwd):/binary-builder" \
    -v "${RUBY_OUT}:/out" \
    -e STACK="${STACK}" \
    "${IMAGE}" \
    bash -c "
      cd /binary-builder
      # ... setup ruby, bundle install ...
      ruby buildpacks-ci/tasks/build-binary-new-cflinuxfs4/build.rb \
        --name=${DEP} --version=${VERSION} --sha256=${SHA256} \
        --skip-commit
      cp artifacts/* /out/artifact/
      cp dep-metadata/* /out/dep-metadata/
      cp builds-artifacts/binary-builds-new/${DEP}/* /out/builds/
    "
}

run_go_builder() {
  docker run --rm \
    -v "$(pwd):/binary-builder" \
    -v "${GO_OUT}:/out" \
    -e STACK="${STACK}" \
    "${IMAGE}" \
    bash -c "
      /binary-builder/bin/binary-builder build \
        --name=${DEP} --version=${VERSION} --sha256=${SHA256} \
        --stack=${STACK} \
        --stacks-dir=/binary-builder/stacks \
        --artifacts-dir=/out/artifact \
        --builds-dir=/out/builds \
        --dep-metadata-dir=/out/dep-metadata \
        --skip-commit
    "
}

compare_outputs() {
  local mismatches=0

  # Compare artifact filenames (pattern match, not exact — SHA prefix may differ for compiled deps)
  ruby_artifact=$(ls "${RUBY_OUT}/artifact/" | head -1)
  go_artifact=$(ls "${GO_OUT}/artifact/" | head -1)

  ruby_pattern=$(echo "${ruby_artifact}" | sed 's/_[0-9a-f]\{8\}\./_./')
  go_pattern=$(echo "${go_artifact}" | sed 's/_[0-9a-f]\{8\}\./_./')

  if [[ "${ruby_pattern}" != "${go_pattern}" ]]; then
    echo "MISMATCH: artifact filename pattern"
    echo "  Ruby: ${ruby_artifact}"
    echo "  Go:   ${go_artifact}"
    mismatches=$((mismatches + 1))
  fi

  # Compare tar contents (sorted file list)
  ruby_files=$(tar -tzf "${RUBY_OUT}/artifact/${ruby_artifact}" | sort)
  go_files=$(tar -tzf "${GO_OUT}/artifact/${go_artifact}" | sort)

  if [[ "${ruby_files}" != "${go_files}" ]]; then
    echo "MISMATCH: tar file list"
    diff <(echo "${ruby_files}") <(echo "${go_files}") || true
    mismatches=$((mismatches + 1))
  fi

  # Compare builds JSON (field by field via jq)
  ruby_json=$(ls "${RUBY_OUT}/builds/"*.json | head -1)
  go_json=$(ls "${GO_OUT}/builds/"*.json | head -1)

  for field in version "source.url" "source.sha256" "source.sha512" "source.md5" url sha256; do
    ruby_val=$(jq -r ".${field} // empty" "${ruby_json}")
    go_val=$(jq -r ".${field} // empty" "${go_json}")
    if [[ "${ruby_val}" != "${go_val}" ]]; then
      echo "MISMATCH: builds JSON field .${field}"
      echo "  Ruby: ${ruby_val}"
      echo "  Go:   ${go_val}"
      mismatches=$((mismatches + 1))
    fi
  done

  # Compare sub_dependencies keys and versions
  ruby_subdeps=$(jq -r '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' "${ruby_json}" | sort)
  go_subdeps=$(jq -r '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' "${go_json}" | sort)

  if [[ "${ruby_subdeps}" != "${go_subdeps}" ]]; then
    echo "MISMATCH: sub_dependencies"
    diff <(echo "${ruby_subdeps}") <(echo "${go_subdeps}") || true
    mismatches=$((mismatches + 1))
  fi

  # Compare dep-metadata JSON
  ruby_meta=$(ls "${RUBY_OUT}/dep-metadata/"*.json | head -1)
  go_meta=$(ls "${GO_OUT}/dep-metadata/"*.json | head -1)

  if ! diff <(jq -S . "${ruby_meta}") <(jq -S . "${go_meta}") > /dev/null 2>&1; then
    echo "MISMATCH: dep-metadata JSON"
    diff <(jq -S . "${ruby_meta}") <(jq -S . "${go_meta}") || true
    mismatches=$((mismatches + 1))
  fi

  return "${mismatches}"
}

run_ruby_builder
run_go_builder
compare_outputs

echo "Parity test PASSED for ${DEP} ${VERSION} on ${STACK}"
```

### 2.3 Determinism table

Not all deps produce byte-for-byte identical artifacts. This table documents what level of
equivalence is expected and why.

| Dep family | Artifact SHA256 match? | Tar contents match? | Notes |
|------------|----------------------|---------------------|-------|
| Passthrough (tomcat, composer, openjdk, zulu, sapmachine, appdynamics, skywalking-agent, jprofiler, your-kit-profiler) | ✅ Exact | ✅ Exact | No transformation; file downloaded and renamed |
| Repack (pip, pipenv, setuptools, yarn, bower, rubygems, dotnet-sdk/runtime/aspnetcore, miniconda) | ✅ Exact | ✅ Exact | Deterministic repack; same strip/prune logic |
| Compiled — Go, dep, glide, godep, hwc | ✅ Exact | ✅ Exact | Cross-compiled; deterministic given same toolchain |
| Compiled — ruby, python, node, nginx, nginx-static, openresty, libunwind, libgdiplus, bundler | ⚠️ May differ | ✅ Must match | Compiled inside Docker; timestamps may vary. Tar file list must be identical; binary must self-report correct version |
| Compiled — httpd | ⚠️ May differ | ✅ Must match | APR/APR-Util versions fetched dynamically from GitHub |
| Compiled — jruby | ⚠️ May differ | ✅ Must match | Maven build; `incorrect_words.yaml` stripped |
| Compiled — r | ⚠️ May differ | ✅ Must match | R packages installed from CRAN; versions pinned but timestamps vary |
| PHP | ⚠️ May differ | ✅ Must match | Extension set must be identical; `.so` files must be present |

**Rule:** For any dep where SHA256 may differ, the parity test asserts tar contents (sorted file
list) and binary self-report instead of artifact SHA256.

### 2.4 Full dep matrix for parity testing

Run parity tests for at least one version of each dep family before cutover:

```
ruby        3.3.6
python      3.12.0
node        20.11.0
go          1.22.0
nginx       1.25.3
nginx-static 1.25.3
openresty   1.25.3.1
httpd       2.4.58
jruby       9.4.5.0-ruby-3.1
bundler     2.5.6
r           4.3.2
libunwind   1.6.2
libgdiplus  6.1
dep         0.5.4
glide       0.13.3
godep       80
hwc         2.0.0
pip         24.0
pipenv      2023.12.1
setuptools  69.0.3
yarn        1.22.21
bower       1.8.14
rubygems    3.5.6
dotnet-sdk  8.0.101
dotnet-runtime 8.0.1
dotnet-aspnetcore 8.0.1
miniconda3-py39 23.11.0
composer    2.7.1
appdynamics 23.11.0
tomcat      10.1.18
openjdk     11.0.22_7
zulu        21.32.17
sapmachine  21.0.2
jprofiler-profiler 13.0.14
your-kit-profiler 2024.3
```

---

## Tier 3 — Exerciser Tests

**Goal:** Verify that the built artifact actually works — the binary runs, reports the correct
version, and (for PHP) has the expected extensions loaded.

**Location:** `binary-builder/test/exerciser/`

**Runner:** `make exerciser-test DEP=ruby VERSION=3.3.6 STACK=cflinuxfs4` — extracts artifact
inside the target stack Docker container and runs the binary.

### 3.1 Exerciser script

```bash
#!/usr/bin/env bash
# binary-builder/test/exerciser/run.sh
# Usage: run.sh <tarball-path> <stack> <command...>
# Extracts the tarball inside the target stack container and runs <command>.

set -euo pipefail

TARBALL="${1:?tarball path required}"
STACK="${2:?stack required}"
shift 2

IMAGE="cloudfoundry/${STACK}"
TARBALL_ABS="$(realpath "${TARBALL}")"
TARBALL_NAME="$(basename "${TARBALL_ABS}")"

docker run --rm \
  -v "${TARBALL_ABS}:/tmp/${TARBALL_NAME}" \
  "${IMAGE}" \
  bash -c "
    mkdir -p /tmp/exerciser
    cd /tmp/exerciser
    tar xzf /tmp/${TARBALL_NAME}
    $*
  "
```

### 3.2 Per-dep exerciser assertions

| Dep | Command | Expected output contains |
|-----|---------|--------------------------|
| ruby | `./bin/ruby -e 'puts RUBY_VERSION'` | `3.3.6` |
| python | `./bin/python3 --version` | `Python 3.12.0` |
| node | `node-v*/bin/node -e 'console.log(process.version)'` | `v20.11.0` |
| go | `./go/bin/go version` | `go1.22.0` |
| nginx | `env LD_LIBRARY_PATH=./lib ./nginx/sbin/nginx -v` | `nginx/1.25.3` |
| nginx-static | `./nginx/sbin/nginx -v` | `nginx/1.25.3` |
| openresty | `./nginx/sbin/nginx -v` | `openresty/1.25.3.1` |
| httpd | `env LD_LIBRARY_PATH=./lib ./httpd/bin/httpd -v` | `Apache/2.4.58` |
| jruby | `./bin/jruby --version` | `9.4.5.0` |
| bundler | `./bin/bundle --version` | `Bundler version 2.5.6` |
| r | `./bin/R --version` | `R version 4.3.2` |
| libunwind | `ls lib/libunwind.so*` | file exists |
| libgdiplus | `ls lib/libgdiplus.so*` | file exists |
| dep | `./dep version` | `0.5.4` |
| glide | `./glide --version` | `0.13.3` |
| godep | `./godep version` | `v80` |
| hwc | `file hwc.exe` | `PE32+ executable` |
| pip | `./bin/pip --version` | `pip 24.0` |
| pipenv | `./bin/pipenv --version` | `pipenv, version 2023.12.1` |
| setuptools | `ls setuptools-*.dist-info/` | directory exists |
| yarn | `./bin/yarn --version` | `1.22.21` |
| rubygems | `ls rubygems-*/` | directory exists |
| dotnet-sdk | `./dotnet --version` | `8.0.101` |
| dotnet-runtime | `./dotnet --version` | `8.0.1` |
| dotnet-aspnetcore | `ls shared/Microsoft.AspNetCore.App/` | directory exists |
| composer | `php composer.phar --version` | `Composer version 2.7.1` |
| tomcat | `ls bin/catalina.sh` | file exists |
| openjdk | `./bin/java -version` | `11.0.22` |
| zulu | `./bin/java -version` | `21.` |
| sapmachine | `./bin/java -version` | `21.0.2` |
| jprofiler-profiler | `ls bin/jprofiler` | file exists |
| your-kit-profiler | `ls lib/yjp.jar` | file exists |

#### PHP exerciser (extended)

PHP requires additional assertions beyond version:

```bash
# Extract and set LD_LIBRARY_PATH
tar xzf php-*.tgz
export LD_LIBRARY_PATH="$PWD/php/lib"

# Version
./php/bin/php --version | grep "PHP 8.3"

# Extension list — assert all expected extensions present
./php/bin/php -m > /tmp/php-modules.txt

# Native modules (always present)
grep -q "^date$"     /tmp/php-modules.txt
grep -q "^json$"     /tmp/php-modules.txt
grep -q "^pcre$"     /tmp/php-modules.txt
grep -q "^Reflection$" /tmp/php-modules.txt
grep -q "^SPL$"      /tmp/php-modules.txt
grep -q "^standard$" /tmp/php-modules.txt

# Key extensions from php8-base-extensions.yml
grep -q "^curl$"     /tmp/php-modules.txt
grep -q "^gd$"       /tmp/php-modules.txt
grep -q "^mbstring$" /tmp/php-modules.txt
grep -q "^mysqli$"   /tmp/php-modules.txt
grep -q "^pdo_mysql$" /tmp/php-modules.txt
grep -q "^redis$"    /tmp/php-modules.txt
grep -q "^imagick$"  /tmp/php-modules.txt
```

### 3.3 Go test harness for exercisers

The exerciser tests are wrapped in a Go test file so they integrate with `go test`:

```go
// binary-builder/test/exerciser/exerciser_test.go
// +build integration

package exerciser_test

import (
    "os"
    "os/exec"
    "testing"
)

func TestRubyBinary(t *testing.T) {
    tarball := os.Getenv("ARTIFACT")  // set by make target
    stack   := os.Getenv("STACK")
    if tarball == "" || stack == "" {
        t.Skip("ARTIFACT and STACK must be set")
    }
    out := runInContainer(t, tarball, stack, "./bin/ruby", "-e", "puts RUBY_VERSION")
    if !strings.Contains(out, "3.3.6") {
        t.Errorf("expected ruby version 3.3.6, got: %s", out)
    }
}
```

Run with:
```bash
ARTIFACT=/tmp/artifacts/ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz \
STACK=cflinuxfs4 \
go test -tags integration ./test/exerciser/ -run TestRubyBinary -v
```

---

## Tier 4 — Concourse Shadow Run

**Goal:** Verify the Go builder in production conditions — real Concourse, real Docker images,
real S3 uploads — before cutting over from the Ruby builder.

**Location:** `buildpacks-ci/pipelines/dependency-builds/`

### 4.1 Shadow pipeline design

The shadow pipeline runs the Go builder task (`build-binary`) in parallel with the existing Ruby
builder task (`build-binary-new-cflinuxfs4`) for every dependency build. The Go task runs with
`SKIP_COMMIT=true` so it does not write to the builds-artifacts git repo.

A downstream compare step diffs the two `dep-metadata/` outputs and fails the pipeline if they
diverge.

```
[source-resource] ──┬──► [build-binary-new-cflinuxfs4 (Ruby)] ──► [builds-artifacts] ──► [downstream buildpack jobs]
                    │
                    └──► [build-binary-go-shadow (Go, SKIP_COMMIT=true)] ──► [compare-outputs] ──► (pass/fail only)
```

### 4.2 Compare task

```yaml
# buildpacks-ci/tasks/compare-build-outputs/task.yml
platform: linux
image_resource:
  type: docker-image
  source: { repository: alpine, tag: latest }

inputs:
  - name: ruby-dep-metadata
  - name: go-dep-metadata

run:
  path: buildpacks-ci/tasks/compare-build-outputs/run.sh
```

```bash
#!/usr/bin/env bash
# buildpacks-ci/tasks/compare-build-outputs/run.sh
set -euo pipefail

ruby_json=$(ls ruby-dep-metadata/*.json | head -1)
go_json=$(ls go-dep-metadata/*.json | head -1)

mismatches=0

for field in version "source.url" "source.sha256" url sha256; do
  ruby_val=$(jq -r ".${field} // empty" "${ruby_json}")
  go_val=$(jq -r ".${field} // empty" "${go_json}")
  if [[ "${ruby_val}" != "${go_val}" ]]; then
    echo "MISMATCH: .${field}"
    echo "  Ruby: ${ruby_val}"
    echo "  Go:   ${go_val}"
    mismatches=$((mismatches + 1))
  fi
done

ruby_subdeps=$(jq -r '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' "${ruby_json}" | sort)
go_subdeps=$(jq -r '.sub_dependencies // {} | to_entries[] | "\(.key)=\(.value.version)"' "${go_json}" | sort)

if [[ "${ruby_subdeps}" != "${go_subdeps}" ]]; then
  echo "MISMATCH: sub_dependencies"
  diff <(echo "${ruby_subdeps}") <(echo "${go_subdeps}") || true
  mismatches=$((mismatches + 1))
fi

if [[ "${mismatches}" -gt 0 ]]; then
  echo "Shadow run FAILED: ${mismatches} mismatch(es)"
  exit 1
fi

echo "Shadow run PASSED"
```

### 4.3 Cutover gate

The Go builder replaces the Ruby builder for cflinuxfs4 only after:

1. **All 35 dep families** have passed at least one shadow run with zero mismatches.
2. **No shadow failures** in the last 7 consecutive days across all dep families.
3. **PHP** has passed a full build + exerciser test (extension list verified).
4. **R** has passed a full build + exerciser test (R packages verified).
5. Manual sign-off from a team member who has reviewed the shadow run logs.

After cutover:
- `build-binary-new-cflinuxfs4/` task is removed from the pipeline.
- `binary-builder/cflinuxfs4/` Ruby code is archived (moved to `binary-builder/cflinuxfs4-archived/`, marked deprecated in README).
- cflinuxfs5 jobs are enabled using the same Go task with `STACK=cflinuxfs5`.

---

## Makefile targets

```makefile
# binary-builder/Makefile

.PHONY: test unit-test parity-test exerciser-test

# Tier 1: unit tests (no Docker)
unit-test:
	go test ./...

# Tier 1 with race detector
unit-test-race:
	go test -race ./...

# Tier 2: parity test for a single dep
# Usage: make parity-test DEP=ruby VERSION=3.3.6 SHA256=abc123 STACK=cflinuxfs4
parity-test:
	@test -n "$(DEP)"     || (echo "DEP is required"; exit 1)
	@test -n "$(VERSION)" || (echo "VERSION is required"; exit 1)
	@test -n "$(SHA256)"  || (echo "SHA256 is required"; exit 1)
	./test/parity/compare-builds.sh "$(DEP)" "$(VERSION)" "$(SHA256)" "$(STACK)"

# Tier 2: parity test for all deps in the matrix
parity-test-all:
	./test/parity/run-all.sh "$(STACK)"

# Tier 3: exerciser test for a single artifact
# Usage: make exerciser-test ARTIFACT=/tmp/ruby_3.3.6_...tgz STACK=cflinuxfs4
exerciser-test:
	@test -n "$(ARTIFACT)" || (echo "ARTIFACT is required"; exit 1)
	@test -n "$(STACK)"    || (echo "STACK is required"; exit 1)
	ARTIFACT="$(ARTIFACT)" STACK="$(STACK)" \
	  go test -tags integration ./test/exerciser/ -v

# Run all tiers (requires Docker)
test: unit-test parity-test-all
```

---

## CI integration

| Tier | Trigger | Pipeline |
|------|---------|----------|
| Tier 1 (unit) | Every PR, every push to main | `binary-builder` GitHub Actions |
| Tier 3 (exerciser) | Every PR that touches a recipe file | `binary-builder` GitHub Actions (Docker available) |
| Tier 2 (parity) | Nightly + manually before cutover | `dependency-builds` Concourse shadow pipeline |
| Tier 4 (shadow run) | Every dep build trigger during shadow period | `dependency-builds` Concourse shadow pipeline |

---

## Known non-determinism and accepted deltas

The following differences between Ruby and Go builder outputs are **expected and accepted**:

| Situation | Expected delta | Reason |
|-----------|---------------|--------|
| Compiled dep artifact SHA256 | May differ | Build timestamps embedded by compiler |
| R package artifact SHA256 | May differ | CRAN packages include build timestamps |
| JRuby artifact SHA256 | May differ | Maven build timestamps |
| `source.sha256` absent in legacy format | Both absent | Legacy `data.json` format has no source SHA |
| `git_commit_sha` in R build | Present in both, must match | Computed from source tarball SHA256 |
| APR/APR-Util version in httpd `sub_dependencies` | Must match | Both builders fetch from same GitHub API |

Any delta **not** in this table is a bug in the Go builder and must be fixed before cutover.
