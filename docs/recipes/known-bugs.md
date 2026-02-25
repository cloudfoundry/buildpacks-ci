# Known Bugs in Ruby Code (to Fix in Go Rewrite)

This document records bugs found in the existing Ruby implementation that the Go rewrite must fix rather than carry forward.

---

## Bug 1: `your-kit-profiler` dispatch is broken

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` line 311

**Code:**
```ruby
method_name = "build_#{@source_input.name.sub('-', '_')}"
```

**Problem:** `String#sub` replaces only the **first** occurrence. `your-kit-profiler` has two hyphens:

```
"your-kit-profiler".sub('-', '_')  → "your_kit-profiler"
```

`build_your_kit-profiler` is not a valid Ruby method name, so `respond_to?` returns false and the build raises `"No build method for your-kit-profiler"`.

The actual method is named `build_your_kit_profiler` (all hyphens replaced), but the dispatch never reaches it.

**Fix in Go:** Use `strings.ReplaceAll(name, "-", "_")` when building the registry lookup key. In practice the Go registry will be a `map[string]Recipe` keyed on the canonical dep name (with hyphens), so this problem does not arise.

---

## Bug 2: `build_python` references `@name` and `@version` (nil)

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` lines 662–663

**Code:**
```ruby
$stdout.print "Running 'install dependencies' for #{@name} #{@version}... "
Runner.run("sudo apt-get update && sudo apt-get -y install #{packages.join(' ')}")
```

**Problem:** `@name` and `@version` are instance variables of `DependencyBuild`, but inside `build_python` the correct references are `@source_input.name` and `@source_input.version`. `@name` and `@version` are never set, so they are `nil`. The log line prints `"Running 'install dependencies' for  ..."` (blank name and version).

Additionally, `Runner.run` is passed a single shell string (`"sudo apt-get update && ..."`) rather than an array of arguments. This works because Ruby's `Kernel#system` will shell-expand a single string, but it is inconsistent with the rest of the codebase and bypasses the `DEBIAN_FRONTEND` env injection.

**Fix in Go:** Use `src.Name` and `src.Version` from the injected `source.Input`. Run apt update and apt install as separate `Runner.Run` calls.

---

## Bug 3: Dead-code methods — `gradle`, `maven`, `wildfly`

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb`

**Methods:** `build_gradle` (line 851), `build_maven` (line 863), `build_wildfly` (line 887)

**Problem:** These methods exist in `builder.rb` but there are **no corresponding entries** in `pipelines/dependency-builds/config.yml` under any `*_dependencies` list. They are never invoked by the pipeline. They are dead code.

**Fix in Go:** Do not port these three methods. If they are ever needed again, they can be added as proper passthrough recipes with config.yml entries.

---

## Bug 4: `build_python` uses deprecated `--force-yes`

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` line 665

**Code:**
```ruby
Runner.run('apt-get -y --force-yes -d install --reinstall libtcl8.6 libtk8.6 libxss1')
```

**Problem:** `--force-yes` is deprecated in apt ≥ 1.1 (Ubuntu 16.04+) and removed in apt 2.x (Ubuntu 22.04+). On cflinuxfs4 it may emit a warning; on cflinuxfs5 (Ubuntu 24.04) it will fail.

**Fix in Go:** The `Stack.Python.UseForceYes` field controls this. `cflinuxfs4.yaml` sets `use_force_yes: true` for compatibility; `cflinuxfs5.yaml` sets `use_force_yes: false`. The `APT.InstallReinstall` method passes `--yes` or `--force-yes` based on this flag.

---

## Bug 5: `build_python` passes shell string to Runner instead of arg array

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` line 663

**Code:**
```ruby
Runner.run("sudo apt-get update && sudo apt-get -y install #{packages.join(' ')}")
```

**Problem:** Passes a single shell string instead of an argument array. This relies on Ruby `Kernel#system` shell expansion and does not inject `DEBIAN_FRONTEND=noninteractive`.

**Fix in Go:** Run as two separate `Runner.Run` calls:
```go
runner.Run("apt-get", "update")
runner.RunWithEnv(map[string]string{"DEBIAN_FRONTEND": "noninteractive"}, "apt-get", "install", append([]string{"-y"}, packages...)...)
```

---

## Bug 6: `build_miniconda` dispatch bypasses method naming entirely

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` lines 308–317

**Code:**
```ruby
def build
  if @source_input.name.include?('miniconda')
    build_miniconda
  else
    method_name = "build_#{@source_input.name.sub('-', '_')}"
    ...
  end
end
```

**Problem:** Miniconda is special-cased before the general dispatch because `miniconda3-py39` contains a digit which would make `build_miniconda3_py39` a syntactically odd method name. The check uses `include?('miniconda')` so any dep name containing "miniconda" triggers this path.

**Fix in Go:** Register `miniconda3-py39` explicitly in the recipe registry by its full name. No special-casing needed.

---

## Summary Table

| # | Bug | Severity | Fix strategy |
|---|-----|----------|-------------|
| 1 | `your-kit-profiler` dispatch broken (`sub` vs `gsub`) | 🔴 High — builds silently fail | Registry map keyed by dep name |
| 2 | `@name`/`@version` nil in `build_python` log line | 🟡 Medium — wrong log output | Use `src.Name`/`src.Version` |
| 3 | `gradle`, `maven`, `wildfly` dead code | 🟡 Medium — misleading | Do not port |
| 4 | `--force-yes` deprecated in apt 2.x | 🟡 Medium — fails on 24.04 | Stack YAML flag + `APT.InstallReinstall` |
| 5 | Shell string passed to Runner in `build_python` | 🟢 Low — works but inconsistent | Two separate Runner.Run calls |
| 6 | Miniconda dispatch special-cased | 🟢 Low — works but fragile | Registry map |
| 7 | `+` in filenames not URL-encoded in S3 URL | 🔴 High — S3 permission denied | `url.PathEscape` or manual `+` → `%2B` |

---

## Bug 7: `+` in artifact filenames causes S3 permission denied

**File:** `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/artifact_output.rb` line 17  
**PR:** [#553](https://github.com/cloudfoundry/buildpacks-ci/pull/553) (merged 2026-02-23)

**Code (before fix):**
```ruby
url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
```

**Code (after fix):**
```ruby
url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename.gsub('+', '%2B')}"
```

**Problem:** Semver v2 allows `+` in version strings (e.g. `openjdk-11.0.22+7`). The `+` character propagates into the artifact filename (e.g. `openjdk_11.0.22+7_linux_x64_cflinuxfs4_abcd1234.tgz`). When this filename is used in the S3 URL without encoding, AWS S3 interprets `+` as a space, causing a permission denied error.

**Fix in Go:** The `Artifact.S3URL` method must URL-encode the filename component. Use `strings.ReplaceAll(filename, "+", "%2B")` to encode `+` characters in the URL path. Do NOT use `url.PathEscape` on the full URL — only encode the filename portion, and only the `+` character needs special handling (other characters in artifact filenames are already safe: alphanumeric, underscore, dot, hyphen).
