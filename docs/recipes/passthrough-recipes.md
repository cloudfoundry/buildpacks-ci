# Passthrough & Repack Recipes

This document is the authoritative spec for all deps that do **not** require compilation — they are downloaded and either passed through directly, repacked with files stripped, or bundled with additional pip packages.

Reference: `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb`

---

## Overview

| Dep name | Build type | Stack-specific artifact? | Any-stack artifact? |
|----------|-----------|--------------------------|---------------------|
| `pip` | pip3 download + bundle | ✅ (`noarch_cflinuxfsN`) | — |
| `pipenv` | pip3 download + bundle | ✅ (`noarch_cflinuxfsN`) | — |
| `setuptools` | direct download + strip | ✅ (`noarch_cflinuxfsN`) | — |
| `yarn` | direct download + strip | ✅ (`noarch_cflinuxfsN`) | — |
| `bower` | direct download | ✅ (`noarch_cflinuxfsN`) | — |
| `rubygems` | direct download + strip | ✅ (`noarch_cflinuxfsN`) | — |
| `dotnet-sdk` | download + prune + xz | ✅ (`x64_cflinuxfsN`) | — |
| `dotnet-runtime` | download + prune + xz | ✅ (`x64_cflinuxfsN`) | — |
| `dotnet-aspnetcore` | download + prune + xz | ✅ (`x64_cflinuxfsN`) | — |
| `miniconda3-py39` | URL passthrough | — | ✅ (URL only, no file) |
| `composer` | direct download | — | ✅ (`noarch_any-stack`) |
| `appdynamics` | direct download | — | ✅ (`noarch_any-stack`) |
| `appdynamics-java` | direct download | — | ✅ (`noarch_any-stack`) |
| `tomcat` | direct download | — | ✅ (`noarch_any-stack`) |
| `skywalking-agent` | direct download | — | ✅ (`noarch_any-stack`) |
| `openjdk` | direct download | ✅ (`x64_cflinuxfsN`) | — |
| `zulu` | direct download | ✅ (`x64_cflinuxfsN`) | — |
| `sapmachine` | direct download | ✅ (`x64_cflinuxfsN`) | — |
| `jprofiler-profiler` | direct download | ✅ (`x64_cflinuxfsN`) | — |
| `your-kit-profiler` | direct download | ✅ (`x64_cflinuxfsN`) | — |

---

## pip

**Ruby method:** `build_pip`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Calls `Utils.setup_python_and_pip` (apt install python3 + pip3 + upgrade pip + setuptools)
2. In a temp dir: `pip3 download --no-binary :all: pip=={version}` (downloads pip source + deps)
3. Downloads the pip source tarball from `source_input.url` (with checksum verification)
4. Strips the top-level directory from the downloaded pip tarball
5. `pip3 download --no-binary :all: setuptools`
6. `pip3 download --no-binary :all: wheel>=0.46.2` (CVE-2026-24049 pin)
7. Bundles everything together: `tar zcvf /tmp/pip-{version}.tgz .`

### Go implementation notes
- `setup_python_and_pip` → call `apt.Install(ctx, "python3", "python3-pip")` then `runner.Run("pip3", "install", "--upgrade", "pip", "setuptools")`
- The CVE pin (`wheel>=0.46.2`) must be preserved exactly — it addresses a known vulnerability
- Output path: `/tmp/pip-{version}.tgz`
- Artifact prefix: `pip_{version}_linux_noarch_{stack}`

---

## pipenv

**Ruby method:** `build_pipenv`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Calls `Utils.setup_python_and_pip`
2. In a temp dir: `pip3 download --no-cache-dir --no-binary :all: pipenv=={version}`
3. Downloads the pipenv source tarball from `source_input.url` (with checksum verification)
4. Downloads 7 additional bundled packages (all `--no-binary :all:`):
   - `pytest-runner`
   - `setuptools_scm`
   - `parver`
   - `wheel>=0.46.2` (CVE-2026-24049 pin)
   - `invoke`
   - `flit_core`
   - `hatch-vcs`
5. Bundles everything: `tar zcvf /tmp/pipenv-v{version}.tgz .`

### Go implementation notes
- Note the `v` prefix in the output filename (`pipenv-v{version}.tgz`) but NOT in the artifact filename prefix (which uses `@filename_prefix = "pipenv_{version}"`)
- The 7 bundled packages are hardcoded — they are build-time dependencies of pipenv itself
- Output path: `/tmp/pipenv-v{version}.tgz`
- Artifact prefix: `pipenv_{version}_linux_noarch_{stack}`

---

## setuptools

**Ruby method:** `build_setuptools`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Downloads from `source_input.url` to `artifacts/temp_{filename}`
2. Strips top-level directory — handles both `.tar.gz`/`.tgz` and `.zip`:
   - If URL ends in `.tar.gz` or `.tgz`: `archive.StripTopLevelDir`
   - Otherwise (`.zip`): `archive.StripTopLevelDirFromZip`

### Go implementation notes
- The filename is inferred from the URL: `url.split('/').last`
- Handle both tar and zip formats — setuptools has shipped as both historically
- Artifact prefix: `setuptools_{version}_linux_noarch_{stack}`

---

## yarn

**Ruby method:** `build_yarn`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Strips `v` prefix from version: `"v1.22.22"` → `"1.22.22"`
2. Downloads from `source_input.url` to `artifacts/temp_file.tgz`
3. Strips top-level directory from the tarball

### Go implementation notes
- Version stripping: `strings.TrimPrefix(src.Version, "v")`
- Artifact prefix uses the stripped version
- Artifact prefix: `yarn_{version}_linux_noarch_{stack}`

---

## bower

**Ruby method:** `build_bower`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Downloads npm tarball directly from `source_input.url` to `artifacts/temp_file.tgz`
2. No repacking — moves as-is

### Go implementation notes
- This is the simplest possible recipe — just download and rename
- Artifact prefix: `bower_{version}_linux_noarch_{stack}`

---

## rubygems

**Ruby method:** `build_rubygems`  
**Artifact arch:** `linux_noarch_{stack}`

### What it does
1. Downloads from `source_input.url` to `artifacts/temp_file.tgz`
2. Strips top-level directory from the tarball

### Go implementation notes
- Artifact prefix: `rubygems_{version}_linux_noarch_{stack}`

---

## dotnet-sdk

**Ruby method:** `build_dotnet_sdk`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `Utils.prune_dotnet_files(source_input, ['./shared/*'], write_runtime=true)`:
   - Finds `source/*.tar.gz`
   - Extracts to temp dir, excluding `./shared/*`
   - Writes `RuntimeVersion.txt` containing the NETCore runtime version (extracted from `tar tf` of the source archive, last entry under `./shared/Microsoft.NETCore.App/`)
   - Re-compresses with `tar -Jcf` (xz) to `/tmp/dotnet-sdk.{version}.linux-amd64.tar.xz`
2. Renames to artifact with `filename_prefix`

### Go implementation notes
- **xz compression** — use `tar -Jcf` not `tar -czf`; output extension is `.tar.xz`
- `RuntimeVersion.txt` content is the basename of the last `./shared/Microsoft.NETCore.App/{version}/` directory entry in the original archive
- Exclude pattern: `./shared/*` (everything under shared, including the `Microsoft.NETCore.App` runtime)
- Artifact prefix: `dotnet-sdk_{version}_linux_x64_{stack}`

---

## dotnet-runtime

**Ruby method:** `build_dotnet_runtime`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `Utils.prune_dotnet_files(source_input, ['./dotnet'])`:
   - Extracts, excluding `./dotnet`
   - Re-compresses with xz
2. No `RuntimeVersion.txt` injection

### Go implementation notes
- Exclude: `./dotnet` binary
- No `RuntimeVersion.txt`
- Artifact prefix: `dotnet-runtime_{version}_linux_x64_{stack}`

---

## dotnet-aspnetcore

**Ruby method:** `build_dotnet_aspnetcore`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
1. `Utils.prune_dotnet_files(source_input, ['./dotnet', './shared/Microsoft.NETCore.App'])`:
   - Excludes both `./dotnet` and `./shared/Microsoft.NETCore.App`
   - Re-compresses with xz
2. No `RuntimeVersion.txt` injection

### Go implementation notes
- Exclude: `./dotnet` AND `./shared/Microsoft.NETCore.App`
- No `RuntimeVersion.txt`
- Artifact prefix: `dotnet-aspnetcore_{version}_linux_x64_{stack}`

---

## miniconda3-py39

**Ruby method:** `build_miniconda` (dispatched specially via `name.include?('miniconda')`)  
**Artifact arch:** N/A — **no file produced**

### What it does
This is the most unusual recipe. It does **not** download a file, does **not** move anything to artifacts. Instead:
1. `HTTPHelper.read_file(@source_input.url)` — GETs the URL body (the installer .sh script)
2. Verifies the checksum of the body
3. Sets `@out_data[:url] = @source_input.url`
4. Sets `@out_data[:sha256] = sha256` (computed from body)

The buildpack downloads miniconda directly at runtime from the CDN URL stored in `out_data`.

### Go implementation notes
- `Cook` returns without producing any artifact file
- Sets `outData.URL` and `outData.SHA256` directly
- Does not call `merge_out_data` / `artifact_output.move_dependency`
- This is why the dispatch in `builder.rb` special-cases it: the normal artifact pipeline doesn't apply
- The Go recipe registry must handle this case: `miniconda3-py39` returns a special `MinicondaRecipe` that satisfies the `Recipe` interface but its `Cook` method sets output data instead of producing a file

---

## composer

**Ruby method:** `build_composer`  
**Artifact arch:** `linux_noarch_any-stack`

### What it does
- Downloads `source/composer.phar` from `source_input.url` (or uses pre-downloaded file if it exists)
- Passes through as-is

### Go implementation notes
- Source file path: `source/composer.phar`
- Artifact prefix: `composer_{version}_linux_noarch_any-stack`

---

## appdynamics

**Ruby method:** `build_appdynamics`  
**Artifact arch:** `linux_noarch_any-stack`

### What it does
- Downloads `source/appdynamics-php-agent-linux_x64-{version}.tar.bz2` from `source_input.url`
- Passes through as-is (just generates the metadata entry)

### Go implementation notes
- This is for PHP agent only — the Java agent is `appdynamics-java`
- Source filename template: `appdynamics-php-agent-linux_x64-{version}.tar.bz2`
- Artifact prefix: `appdynamics_{version}_linux_noarch_any-stack`
- Comment in Ruby: "this code is doing nothing except generating a buildpacks-ci-robot metadata entry" — the PHP buildpack downloads from the original URL

---

## appdynamics-java

**Ruby method:** `build_appdynamics_java`  
**Artifact arch:** `linux_noarch_any-stack`

### What it does
- Downloads `source/appdynamics-java-agent-{version}.zip` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `appdynamics-java-agent-{version}.zip`
- Artifact prefix: `appdynamics-java_{version}_linux_noarch_any-stack`
- Note: requires Credhub credentials in the Concourse pipeline (not relevant to the build binary itself)

---

## tomcat

**Ruby method:** `build_tomcat`  
**Artifact arch:** `linux_noarch_any-stack`

### What it does
- Downloads `source/apache-tomcat-{version}.tar.gz` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `apache-tomcat-{version}.tar.gz`
- Artifact prefix: `tomcat_{version}_linux_noarch_any-stack`

---

## skywalking-agent

**Ruby method:** `build_skywalking_agent`  
**Artifact arch:** `linux_noarch_any-stack`

### What it does
- Downloads `source/apache-skywalking-java-agent-{version}.tgz` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `apache-skywalking-java-agent-{version}.tgz`
- Artifact prefix: `skywalking-agent_{version}_linux_noarch_any-stack`

---

## openjdk (BellSoft Liberica JRE)

**Ruby method:** `build_openjdk`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
- Downloads `source/bellsoft-jre{version}-linux-amd64.tar.gz` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `bellsoft-jre{version}-linux-amd64.tar.gz`
- Artifact prefix: `openjdk_{version}_linux_x64_{stack}`
- The `jruby` config in `stacks/*.yaml` provides the JDK used for building JRuby — this recipe is separate and tracks the JRE artifact for the java buildpack

---

## zulu (Azul Zulu JRE)

**Ruby method:** `build_zulu`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
- Downloads `source/zulu{version}-jre-linux_x64.tar.gz` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `zulu{version}-jre-linux_x64.tar.gz`
- Artifact prefix: `zulu_{version}_linux_x64_{stack}`

---

## sapmachine (SAP Machine JRE)

**Ruby method:** `build_sapmachine`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
- Downloads `source/sapmachine-jre-{version}_linux-x64_bin.tar.gz` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `sapmachine-jre-{version}_linux-x64_bin.tar.gz`
- Artifact prefix: `sapmachine_{version}_linux_x64_{stack}`

---

## jprofiler-profiler

**Ruby method:** `build_jprofiler_profiler`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
- Downloads `source/jprofiler_linux_{version_with_underscores}.tar.gz`
- Version dots are replaced with underscores: `"13.0.14"` → `"13_0_14"`
- Passes through as-is

### Go implementation notes
- Source filename: `jprofiler_linux_{strings.ReplaceAll(version, ".", "_")}.tar.gz`
- Artifact prefix: `jprofiler-profiler_{version}_linux_x64_{stack}`

---

## your-kit-profiler

**Ruby method:** `build_your_kit_profiler`  
**Artifact arch:** `linux_x64_{stack}`

### What it does
- Downloads `source/YourKit-JavaProfiler-{version}.zip` from `source_input.url`
- Passes through as-is

### Go implementation notes
- Source filename template: `YourKit-JavaProfiler-{version}.zip`
- Artifact prefix: `your-kit-profiler_{version}_linux_x64_{stack}`
- **See `docs/recipes/known-bugs.md` Bug #1** — the Ruby dispatch for this method is broken. The Go registry will use the full dep name `your-kit-profiler` as the key, so this issue does not exist in Go.

---

## Generic Passthrough Pattern

Most "any-stack" passthrough deps follow this exact pattern (composer, appdynamics, tomcat, skywalking-agent, appdynamics-java):

```go
// passthrough.go — one handler covers all of these

type PassthroughRecipe struct {
    depName          string
    sourceFilenameFunc func(version string) string
    stack            string   // "any-stack" or stack name
    arch             string   // "noarch", "x64", "x86-64"
    os               string   // "linux", "windows"
}

func (p *PassthroughRecipe) Cook(ctx context.Context, s stack.Stack, src source.Input) error {
    localPath := filepath.Join("source", p.sourceFilenameFunc(src.Version))
    if _, err := os.Stat(localPath); os.IsNotExist(err) {
        if err := fetcher.Download(ctx, src.URL, localPath, src.PrimaryChecksum()); err != nil {
            return err
        }
    }
    return nil
}
```

The registry wires up each dep with its specific `sourceFilenameFunc` and `arch`/`stack` values.
