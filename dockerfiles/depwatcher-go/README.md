# Depwatcher

A Concourse resource implementation for watching dependency releases. Depwatcher monitors various sources for new versions of programming languages, frameworks, libraries, and tools used in Cloud Foundry buildpacks.

## Overview

Depwatcher provides a unified interface to check for new releases across 39 different dependency sources, from programming languages (Ruby, Python, Node.js, Go, Java) to web servers (Nginx, Apache, Tomcat, WildFly), package managers (NPM, PyPI, RubyGems, Maven), and specialized tools (.NET SDKs, R packages, APM agents, JDK distributions, Java profilers).

**Key Features:**
- **39 supported dependency sources** - Languages, frameworks, tools, libraries, and JDKs
- **Flexible version filtering** - Track specific version lines (e.g., Ruby 3.2.x, PHP 8.3.x, Tomcat 9.x)
- **API-first architecture** - Reliable data from official APIs (GitHub, NPM, PyPI, Maven, etc.)
- **Production ready** - 273 passing tests with comprehensive coverage
- **Concourse native** - Standard `check` and `in` operations

## Quick Start

### Building

```bash
# Build both commands
go build -o check ./cmd/check
go build -o in ./cmd/in
```

### Basic Usage

**Check for new releases:**
```bash
echo '{"source":{"type":"node","version_filter":"node-lts"}}' | ./check
```

**Fetch specific version:**
```bash
echo '{"source":{"type":"node"},"version":{"ref":"20.11.0"}}' | ./in /tmp/output
```

## Supported Sources

### Programming Languages

| Type | Description | Example |
|------|-------------|---------|
| `ruby` | Ruby releases from ruby-lang.org | `{"type":"ruby","version_filter":"3.3"}` |
| `jruby` | JRuby releases via GitHub | `{"type":"jruby"}` |
| `python` | Python releases from python.org | `{"type":"python","version_filter":"3.12"}` |
| `node` | Node.js releases (LTS support) | `{"type":"node","version_filter":"node-lts"}` |
| `php` | PHP releases via php.watch | `{"type":"php","version_filter":"8.3"}` |
| `go` | Go releases via go.dev API | `{"type":"go"}` |
| `r` | R language releases | `{"type":"r","version_filter":"4.4"}` |

### .NET Ecosystem

| Type | Description | Example |
|------|-------------|---------|
| `dotnet-sdk` | .NET SDK releases | `{"type":"dotnet-sdk","version_filter":"8.0"}` |
| `dotnet-runtime` | .NET Runtime releases | `{"type":"dotnet-runtime","version_filter":"8.0"}` |
| `dotnet-aspnetcore` | ASP.NET Core releases | `{"type":"dotnet-aspnetcore"}` |

### Package Managers & Registries

| Type | Description | Example |
|------|-------------|---------|
| `npm` | NPM package registry | `{"type":"npm","name":"typescript"}` |
| `pypi` | Python Package Index | `{"type":"pypi","name":"pip"}` |
| `rubygems` | RubyGems packages | `{"type":"rubygems","name":"bundler"}` |
| `rubygems_cli` | RubyGems CLI tool | `{"type":"rubygems_cli"}` |

### Web Servers & Tools

| Type | Description | Example |
|------|-------------|---------|
| `nginx` | Nginx web server | `{"type":"nginx","version_filter":"1.27"}` |
| `httpd` | Apache HTTP Server | `{"type":"httpd"}` |
| `openresty` | OpenResty platform | `{"type":"openresty"}` |
| `icu` | ICU library | `{"type":"icu"}` |
| `miniconda` | Miniconda distributions | `{"type":"miniconda"}` |

### R Ecosystem (CRAN)

| Type | Description | Example |
|------|-------------|---------|
| `rserve` | Rserve package | `{"type":"rserve"}` |
| `forecast` | forecast package | `{"type":"forecast"}` |
| `plumber` | plumber package | `{"type":"plumber"}` |
| `shiny` | shiny package | `{"type":"shiny"}` |

### APM Agents

| Type | Description | Example |
|------|-------------|---------|
| `appd_agent` | AppDynamics PHP Agent | `{"type":"appd_agent"}` |
| `ca_apm_agent` | CA APM PHP Agent | `{"type":"ca_apm_agent"}` |

### Java Dependencies

| Type | Description | Required Fields | Example |
|------|-------------|----------------|---------|
| `gradle` | Gradle build tool | None | `{"type":"gradle"}` |
| `maven` | Maven artifacts | `uri`, `group_id`, `artifact_id` | `{"type":"maven","uri":"https://repo1.maven.org/maven2","group_id":"org.springframework.boot","artifact_id":"spring-boot"}` |
| `tomcat` | Apache Tomcat | `uri` | `{"type":"tomcat","uri":"https://archive.apache.org/dist/tomcat/tomcat-9"}` |
| `wildfly` | WildFly application server | None | `{"type":"wildfly"}` |
| `corretto` | Amazon Corretto JDK | `owner`, `repository` | `{"type":"corretto","owner":"corretto","repository":"corretto-8"}` |
| `liberica` | Bellsoft Liberica JDK | `version`, `product`, `bundle_type` | `{"type":"liberica","version":"11","product":"jdk","bundle_type":"jdk"}` |
| `zulu` | Azul Zulu JDK | `version`, `bundle_type` | `{"type":"zulu","version":"8","bundle_type":"jdk"}` |
| `adoptopenjdk` | AdoptOpenJDK (EOL) | `version`, `implementation`, `jdk_type` | `{"type":"adoptopenjdk","version":"8","implementation":"hotspot","jdk_type":"jdk"}` |
| `artifactory` | Artifactory repository | `uri`, `group_id`, `artifact_id` | `{"type":"artifactory","uri":"https://repo.example.com","group_id":"com.example","artifact_id":"myapp"}` |
| `jprofiler` | JProfiler profiler | None | `{"type":"jprofiler"}` |
| `yourkit` | YourKit profiler | None | `{"type":"yourkit"}` |
| `skywalking` | Apache SkyWalking agent | None | `{"type":"skywalking"}` |

### GitHub Sources

| Type | Required Fields | Description | Example |
|------|----------------|-------------|---------|
| `github_releases` | `repo` | GitHub releases with assets | `{"type":"github_releases","repo":"cloudfoundry/hwc"}` |
| `github_tags` | `repo`, `tag_regex` | GitHub tags with filtering | `{"type":"github_tags","repo":"mono/libgdiplus","tag_regex":"^[0-9]+"}` |

## Configuration

### Version Filtering

Filter versions to track specific release lines:

```bash
# Track Ruby 3.3.x versions
echo '{"source":{"type":"ruby","version_filter":"3.3"}}' | ./check

# Track PHP 8.2.x versions  
echo '{"source":{"type":"php","version_filter":"8.2"}}' | ./check

# Track all LTS Node.js versions
echo '{"source":{"type":"node","version_filter":"node-lts"}}' | ./check

# Track Go 1.23.x versions
echo '{"source":{"type":"go","version_filter":"1.23"}}' | ./check
```

### GitHub Authentication

For GitHub-based sources, provide a personal access token:

```json
{
  "source": {
    "type": "github_releases",
    "repo": "cloudfoundry/hwc",
    "github_token": "ghp_your_token_here"
  }
}
```

The token is automatically injected as `OAUTH_AUTHORIZATION_TOKEN` and redacted from logs.

### GitHub Releases Options

```json
{
  "source": {
    "type": "github_releases",
    "repo": "composer/composer",
    "extension": ".phar",
    "prerelease": false,
    "fetch_source": true,
    "version_filter": "2.X"
  }
}
```

- `extension`: Filter releases by asset file extension
- `prerelease`: Include pre-release versions (default: false)
- `fetch_source`: Fetch source tarball if no matching assets (default: false)
- `version_filter`: Semver pattern matching

### Java Dependencies Configuration

**Maven Repositories:**
```json
{
  "source": {
    "type": "maven",
    "uri": "https://repo1.maven.org/maven2",
    "group_id": "org.springframework.boot",
    "artifact_id": "spring-boot",
    "packaging": "jar",
    "classifier": "sources",
    "username": "((maven_user))",
    "password": "((maven_pass))"
  }
}
```

- `uri`: Maven repository base URL
- `group_id`: Maven group ID (dots become slashes in path)
- `artifact_id`: Maven artifact ID
- `packaging`: Artifact packaging type (default: "jar")
- `classifier`: Optional classifier (e.g., "sources", "javadoc")
- `username`/`password`: Optional Basic Auth credentials

**Tomcat Versions:**
```json
{
  "source": {
    "type": "tomcat",
    "uri": "https://archive.apache.org/dist/tomcat/tomcat-9"
  }
}
```

**JDK Distributions:**
```json
{
  "source": {
    "type": "liberica",
    "version": "11",
    "product": "jdk",
    "bundle_type": "jdk",
    "token": "Authorization: Bearer ((api_token))"
  }
}
```

```json
{
  "source": {
    "type": "corretto",
    "owner": "corretto",
    "repository": "corretto-8"
  }
}
```

```json
{
  "source": {
    "type": "zulu",
    "version": "8",
    "bundle_type": "jdk"
  }
}
```

**Artifactory:**
```json
{
  "source": {
    "type": "artifactory",
    "uri": "https://artifactory.example.com",
    "group_id": "com.example",
    "artifact_id": "myapp",
    "artifact_pattern": ".*\\.jar$",
    "username": "((artifactory_user))",
    "password": "((artifactory_pass))"
  }
}
```

- `artifact_pattern`: Regex pattern to filter artifacts (optional)

## Concourse Resource Type

Use in your Concourse pipeline:

```yaml
resource_types:
  - name: depwatcher
    type: registry-image
    source:
      repository: your-registry/depwatcher
      tag: latest

resources:
  - name: node-lts
    type: depwatcher
    source:
      type: node
      version_filter: node-lts

  - name: ruby-3-3
    type: depwatcher
    source:
      type: ruby
      version_filter: "3.3"

  # Java dependency examples
  - name: gradle
    type: depwatcher
    source:
      type: gradle

  - name: tomcat-9
    type: depwatcher
    source:
      type: tomcat
      uri: https://archive.apache.org/dist/tomcat/tomcat-9

  - name: corretto-8
    type: depwatcher
    source:
      type: corretto
      owner: corretto
      repository: corretto-8

  - name: spring-boot
    type: depwatcher
    source:
      type: maven
      uri: https://repo1.maven.org/maven2
      group_id: org.springframework.boot
      artifact_id: spring-boot

jobs:
  - name: update-dependencies
    plan:
      - get: node-lts
        trigger: true
      - get: ruby-3-3
        trigger: true
      - get: gradle
        trigger: true
      - get: tomcat-9
        trigger: true
```

## Development

### Running Tests

```bash
# Run all tests
~/go/bin/ginkgo -r

# Run with coverage
~/go/bin/ginkgo -r --cover

# Run specific watcher tests
~/go/bin/ginkgo -r --focus="NodeWatcher"

# Watch mode for TDD
~/go/bin/ginkgo watch -r
```

### Test Coverage

- **273 passing unit tests** across all components
- **Factory tests** - Watcher routing and initialization  
- **Base tests** - HTTP client and common types
- **Semver tests** - Version parsing and filtering
- **Watcher tests** - All 39 dependency sources including 12 Java-specific watchers

### Project Structure

```
depwatcher-go/
├── cmd/
│   ├── check/          # Concourse check operation
│   └── in/             # Concourse in operation
├── pkg/
│   ├── base/           # HTTP client and common types
│   ├── semver/         # Semver parsing and filtering
│   └── watchers/       # Individual dependency watchers
└── internal/
    └── factory/        # Watcher factory pattern
```

### Adding a New Watcher

1. Create watcher implementation in `pkg/watchers/`:
   ```go
   type MyWatcher struct {
       client base.HTTPClient
   }
   
   func (w *MyWatcher) Check() ([]base.Internal, error) {
       // Fetch and return versions
   }
   
   func (w *MyWatcher) In(ref string) (base.Release, error) {
       // Return release details
   }
   ```

2. Add factory case in `internal/factory/factory.go`:
   ```go
   case "mytype":
       return watchers.NewMyWatcher(client), nil
   ```

3. Add comprehensive tests in `pkg/watchers/my_watcher_test.go`

4. Update `E2E_TEST_RESULTS.md` with real-world validation

## Dependencies

- [Ginkgo v2](https://github.com/onsi/ginkgo) - BDD testing framework
- [Gomega](https://github.com/onsi/gomega) - Assertion library
- [goquery](https://github.com/PuerkitoBio/goquery) - HTML parsing (select watchers)
- [gopkg.in/yaml.v3](https://gopkg.in/yaml.v3) - YAML parsing (Ruby watcher)

## Architecture

Depwatcher follows a clean, modular architecture:

- **API-first approach** - Prefer official APIs over HTML scraping
- **Dependency injection** - HTTP clients are injectable for testing
- **Factory pattern** - Central routing to appropriate watchers
- **Semantic versioning** - Full semver parsing with filtering support
- **Error handling** - Explicit error returns with context

## Team Standards

This implementation follows Cloud Foundry Buildpacks team conventions:

- **Go-based** - Aligns with team's primary language
- **Ginkgo/Gomega testing** - BDD-style test suites
- **Comprehensive testing** - High coverage with unit and E2E tests
- **Clean architecture** - Separation of concerns and testability

## License

Apache License 2.0
