# PHP Recipe

This document is the authoritative spec for the PHP build — the most complex recipe, involving ~35 extension types and a multi-step native library build.

Reference: `binary-builder/cflinuxfs4/recipe/php_meal.rb`, `php_recipe.rb`, `php_common_recipes.rb`  
Reference: `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/builder.rb` (`build_php`)  
Reference: `buildpacks-ci/tasks/build-binary-new-cflinuxfs4/php_extensions/`

---

## Overview

The PHP build has three major parts:

1. **`PHPMeal`** — the orchestrator: installs system packages, creates symlinks, builds native libraries, then delegates to `PHPRecipe`
2. **`PHPRecipe`** — the core: configures and compiles PHP itself, then builds each extension
3. **Extension recipes** — ~22 recipe types covering 44+ extensions

**Artifact arch:** `linux_x64_{stack}`

---

## Step 1: Extension YAML loading (before build starts)

Before calling `binary_builder.build`, the `build_php` method in `builder.rb` loads and merges the extension YAML:

```
base file:  php_extensions/php{major}-base-extensions.yml   (e.g. php8-base-extensions.yml)
patch file: php_extensions/php{major}{minor}-extensions-patch.yml  (e.g. php83-extensions-patch.yml)
```

The patch file can:
- Add new extensions
- Remove extensions (e.g. `yaf` removed in PHP 8.2+)
- Override versions (e.g. `oci8` version differs by minor version)

The merged result is written to `php_extensions/php-final-extensions.yml` and passed to `binary_builder` as `--php-extensions-file=`.

### Go implementation (`internal/php/extensions.go`)

```go
// Load reads the base YAML for the given major version, applies the patch YAML
// for the given major+minor version, and returns the merged ExtensionSet.
func Load(extensionsDir, phpMajor, phpMinor string) (*ExtensionSet, error)
```

Merge rules:
1. Start with base YAML (`native_modules` + `extensions` arrays)
2. For each entry in patch YAML: if `version` or `md5` differ → override; if a patch entry has `remove: true` → delete from set

---

## Step 2: System packages and symlinks (`PHPMeal`)

### Apt packages
All packages come from `stack.AptPackages["php_build"]`. The Go recipe does not contain any package names.

**cflinuxfs4 packages** (from `stacks/cflinuxfs4.yaml`):
```
automake, firebird-dev, libaspell-dev, libc-client2007e-dev, libcurl4-openssl-dev,
libdb-dev, libedit-dev, libenchant-2-dev, libexpat1-dev, libgdbm-dev, libgeoip-dev,
libgmp-dev, libgpgme11-dev, libjpeg-dev, libkrb5-dev, libldap2-dev,
libmagickwand-dev, libmagickcore-dev, libmaxminddb-dev, libmcrypt-dev,
libmemcached-dev, libonig-dev, libpng-dev, libpspell-dev, librecode-dev,
libsasl2-dev, libsnmp-dev, libsqlite3-dev, libssh2-1-dev, libssl-dev, libtidy-dev,
libtool, libwebp-dev, libxml2-dev, libzip-dev, libzookeeper-mt-dev,
snmp-mibs-downloader, sqlite3, unixodbc-dev
```

**cflinuxfs5 differences:**
- `libdb-dev` → `libdb5.3-dev`
- `libzookeeper-mt-dev` — omitted (not available on 24.04)
- `libcjose-dev` in `httpd_build` — availability uncertain; in `php_build` it's not listed but verify

### Symlinks
All symlinks come from `stack.PHPSymlinks`. The Go recipe iterates the list — no hardcoded paths.

**cflinuxfs4 symlinks:**
```
/usr/include/x86_64-linux-gnu/curl     → /usr/local/include/curl
/usr/include/x86_64-linux-gnu/gmp.h   → /usr/include/gmp.h
/usr/lib/x86_64-linux-gnu/libldap.so  → /usr/lib/libldap.so
/usr/lib/x86_64-linux-gnu/libldap_r.so → /usr/lib/libldap_r.so   ← ABSENT on cflinuxfs5
```

**cflinuxfs5:** The `libldap_r` entry is simply not present in `stacks/cflinuxfs5.yaml`. No `if/switch` needed in Go.

---

## Step 3: PHP core configure and compile (`PHPRecipe`)

`./configure` flags (hardcoded — not stack-specific):
```
--disable-static
--enable-shared
--enable-bcmath=shared
--enable-calendar=shared
--enable-dba=shared
--enable-exif=shared
--enable-fpm
--enable-ftp=shared
--enable-gd=shared
--enable-intl=shared
--enable-mbstring=shared
--enable-opcache=shared
--enable-pcntl=shared
--enable-soap=shared
--enable-sockets=shared
--enable-shmop=shared
--enable-sysvmsg=shared
--enable-sysvsem=shared
--enable-sysvshm=shared
--enable-zip=shared
... (plus with-* flags for each enabled extension)
```

### setup_tar: bundled libs
After `make install`, `PHPRecipe#setup_tar` copies shared libraries into the PHP install prefix so the artifact is self-contained:

```bash
cp -a /usr/lib/x86_64-linux-gnu/libmcrypt.so* {prefix}/lib/
cp -a /usr/lib/x86_64-linux-gnu/libonig.so*   {prefix}/lib/
# etc.
```

⚠️ `libmcrypt.so` availability on Ubuntu 24.04 needs verification before cflinuxfs5 can build PHP.

---

## Step 4: Extension recipes

Each extension in `php-final-extensions.yml` specifies a `klass` field. The Go `internal/php` package maps klass names to recipe implementations.

### Extension klass inventory

| Klass | Count | What it does |
|-------|-------|-------------|
| `PeclRecipe` | 20 | Downloads from `pecl.php.net/get/{name}-{version}.tgz`, phpize + configure + make |
| `FakePeclRecipe` | 4 | Built-in PHP extension (tidy, enchant, pdo_firebird, readline, zip) — no external download; uses PHP's own configure |
| `AmqpPeclRecipe` | 1 | Same as PeclRecipe with custom configure options |
| `MaxMindRecipe` | 1 | PeclRecipe variant for maxminddb |
| `HiredisRecipe` | 1 | PkgConfigLib: builds hiredis from source, then builds phpiredis via PECL |
| `ImagickRecipe` | 0* | Builds ImageMagick from source, then imagick PECL (not listed separately — via PeclRecipe for `imagick`) |
| `LibSodiumRecipe` | 1 | PkgConfigLib: builds libsodium from source |
| `IonCubeRecipe` | 1 | Downloads pre-built ioncube loader binary (no compile) |
| `LuaPeclRecipe` | 0 | PeclRecipe variant for lua |
| `LuaRecipe` | 1 | Builds Lua from source, then lua PECL |
| `MemcachedPeclRecipe` | 1 | PeclRecipe with libmemcached configure path |
| `OdbcRecipe` | 1 | FakePeclRecipe for ODBC |
| `PdoOdbcRecipe` | 1 | FakePeclRecipe for PDO ODBC |
| `SodiumRecipe` | 1 | FakePeclRecipe for sodium (built-in PHP 7.2+) |
| `OraclePeclRecipe` | 1 | Builds oci8 — requires Oracle Instant Client |
| `OraclePdoRecipe` | 1 | Builds pdo_oci — requires Oracle Instant Client |
| `PHPIRedisRecipe` | 1 | PeclRecipe for phpiredis (depends on hiredis) |
| `RabbitMQRecipe` | 1 | PkgConfigLib: builds rabbitmq-c from source, then amqp PECL |
| `RedisPeclRecipe` | 1 | PeclRecipe for redis (custom configure: igbinary support) |
| `SnmpRecipe` | 1 | FakePeclRecipe for snmp |
| `TidewaysXhprofRecipe` | 1 | PeclRecipe for tideways_xhprof |
| `LibRdKafkaRecipe` | 1 | PkgConfigLib: builds librdkafka from source |
| `Gd74FakePeclRecipe` | 1 | FakePeclRecipe for gd (PHP 7.4+ uses bundled GD) |
| `EnchantFakePeclRecipe` | 1 | FakePeclRecipe for enchant |

*`ImagickRecipe` is defined in the Ruby code but the extension YAML uses `PeclRecipe` for `imagick` in PHP 8.x — the ImageMagick library is assumed to be already present via `libmagickwand-dev` apt package.

### Extensions in php8-base-extensions.yml

**Native modules** (built before PHP itself — shared libraries that PHP links against):
- `rabbitmq` (RabbitMQRecipe) — builds rabbitmq-c 0.11.0
- `lua` (LuaRecipe) — builds Lua 5.4.6
- `hiredis` (HiredisRecipe) — builds hiredis 1.2.0
- `snmp` (SnmpRecipe) — no external build (system snmp)
- `librdkafka` (LibRdKafkaRecipe) — builds librdkafka 2.3.0
- `libsodium` (LibSodiumRecipe) — builds libsodium 1.0.19

**Extensions** (built after PHP — PECL or fake PECL):
- `apcu`, `igbinary`, `gnupg`, `imagick`, `LZF`, `mailparse`, `mongodb`, `msgpack`, `oauth` — PeclRecipe
- `odbc` (OdbcRecipe), `pdo_odbc` (PdoOdbcRecipe)
- `pdo_sqlsrv`, `rdkafka`, `ssh2`, `sqlsrv`, `stomp`, `xdebug`, `yaf`, `yaml` — PeclRecipe
- `memcached` (MemcachedPeclRecipe)
- `sodium` (SodiumRecipe)
- `tidy` (FakePeclRecipe), `enchant` (EnchantFakePeclRecipe), `pdo_firebird`, `readline`, `zip` (FakePeclRecipe)
- `amqp` (AmqpPeclRecipe), `maxminddb` (MaxMindRecipe)
- `psr`, `phalcon` — PeclRecipe
- `phpiredis` (PHPIRedisRecipe), `tideways_xhprof` (TidewaysXhprofRecipe)
- `solr` — PeclRecipe
- `oci8` (OraclePeclRecipe), `pdo_oci` (OraclePdoRecipe)
- `gd` (Gd74FakePeclRecipe)
- `ioncube` (IonCubeRecipe)

---

## Step 5: `out_data[:sub_dependencies]`

After the build, `build_php` in `builder.rb` populates `out_data[:sub_dependencies]` with the version of every extension:

```go
outData.SubDependencies = map[string]SubDep{}
for _, ext := range append(extSet.NativeModules, extSet.Extensions...) {
    outData.SubDependencies[ext.Name] = SubDep{Version: ext.Version}
}
// Sorted alphabetically by name (case-insensitive)
```

---

## Go package structure

```
internal/php/
├── extensions.go         # ExtensionSet, Load (base + patch merge)
├── extensions_test.go
├── recipe.go             # ExtensionRecipe interface + RecipeFor(klass) factory
├── pecl.go               # PeclRecipe, AmqpPeclRecipe, MaxMindRecipe, RedisPeclRecipe, etc.
├── fake_pecl.go          # FakePeclRecipe, SodiumRecipe, OdbcRecipe, PdoOdbcRecipe, etc.
├── pkgconfig.go          # PkgConfigLibRecipe base + HiredisRecipe, RabbitMQRecipe, etc.
├── native.go             # LuaRecipe, LibSodiumRecipe, LibRdKafkaRecipe, SnmpRecipe
├── special.go            # IonCubeRecipe, OraclePeclRecipe, OraclePdoRecipe, PHPIRedisRecipe
└── gd.go                 # Gd74FakePeclRecipe

internal/recipe/
├── php.go                # PHPRecipe: apt install, symlinks, native modules, extensions, setup_tar
```

---

## Stack-specific checklist for PHP

| Item | cflinuxfs4 | cflinuxfs5 | Source |
|------|-----------|-----------|--------|
| `libdb-dev` | ✅ available | ⚠️ use `libdb5.3-dev` | stack YAML |
| `libzookeeper-mt-dev` | ✅ available | ❌ not available (omit) | stack YAML |
| `libldap_r.so` symlink | ✅ create | ❌ omit (dropped in OpenLDAP 2.6) | stack YAML |
| `libmcrypt.so` in setup_tar | ✅ available | ⚠️ needs verification | runtime |
| `libcjose-dev` (httpd) | ✅ available | ⚠️ needs verification | stack YAML |
