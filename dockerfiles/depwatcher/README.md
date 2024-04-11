# Depwatcher

A concourse resource to watch for new releases of dependencies.

The Buildpacks team use this to build new dependencies for buildpacks.

The various depwatchers in this resource (in `src`) are written in Crystal, as are the tests (in `spec`).

## Run unit tests

`crystal spec --no-debug`

### Notes

- You may need to install dependencies via `crystal deps` before running tests.
- You may need to set `export PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig"` if crystal fails link against `libssl`.

## Building/Pushing

To build locally:
`docker build -t mydepwatcherresource .`

The
[resources/build-and-push-depwatcher](https://buildpacks.ci.cf-app.com/teams/core-deps/pipelines/resources)
is responsible for building and pushing the production-level image to `index.docker.io/coredeps/depwatcher`

## Example run

```
# Check for new versions of a dependency
## HWC
Command
$ echo '{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}' | crystal src/check.cr

Output
{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}
[{"ref":"1.0.0"},{"ref":"1.0.1"},{"ref":"2.0.0"}]

## Node
Command
$ echo '{"source":{"type":"node", "version_filter":"node-lts"}}' | crystal src/check.cr

Output
{"source":{"type":"node","version_filter":"node-lts"}}
[{"ref":"16.0.0"},{"ref":"16.1.0"},{"ref":"16.2.0"},{"ref":"16.3.0"},{"ref":"16.4.0"},{"ref":"16.4.1"},{"ref":"16.4.2"},{"ref":"16.5.0"},{"ref":"16.6.0"},{"ref":"16.6.1"},{"ref":"16.6.2"},{"ref":"16.7.0"},{"ref":"16.8.0"},{"ref":"16.9.0"},{"ref":"16.9.1"},{"ref":"16.10.0"},{"ref":"16.11.0"},{"ref":"16.11.1"},{"ref":"16.12.0"},{"ref":"16.13.0"},{"ref":"16.13.1"},{"ref":"16.13.2"},{"ref":"16.14.0"},{"ref":"16.14.1"},{"ref":"16.14.2"},{"ref":"16.15.0"}]

# Get information about a specific version of a dependency
## Httpd

Command
$ echo'{"source":{"type":"httpd"}, "version":{"ref":"2.4.59"}}' | crystal src/in.cr -- /tmp

Output
{"source":{"type":"httpd"},"version":{"ref":"2.4.59"}}
{"ref":"2.4.59","url":"https://dlcdn.apache.org/httpd/httpd-2.4.59.tar.bz2","sha256":"ec51501ec480284ff52f637258135d333230a7d229c3afa6f6c2f9040e321323"}
{"version":{"ref":"2.4.59"}}
```
