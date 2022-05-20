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

`docker build -t cfbuildpacks/depwatcher .`

`docker push cfbuildpacks/depwatcher`

## Example run

```
## HWC
$ echo '{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}' | crystal src/check.cr
  {"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}
  [{"ref":"1.0.0"},{"ref":"1.0.1"},{"ref":"2.0.0"}]

$ echo '{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"},"version":{"ref":"2.0.0"}}' | crystal src/in.cr -- /tmp
  {"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"},"version":{"ref":"2.0.0"}}
{"ref":"2.0.0","url":"https://github.com/cloudfoundry/hwc/releases/download/2.0.0/hwc.exe","sha256":"1bad9c61262702404653f4d043d79082e8a181ee33e2c1e11db3eb346e7fcd33"}
{"version":{"ref":"2.0.0"}}

## Node
$ echo '{"source":{"type":"node", "version_filter":"node-lts"}}' | crystal src/check.cr
  {"source":{"type":"node","version_filter":"node-lts"}}
  [{"ref":"16.0.0"},{"ref":"16.1.0"},{"ref":"16.2.0"},{"ref":"16.3.0"},{"ref":"16.4.0"},{"ref":"16.4.1"},{"ref":"16.4.2"},{"ref":"16.5.0"},{"ref":"16.6.0"},{"ref":"16.6.1"},{"ref":"16.6.2"},{"ref":"16.7.0"},{"ref":"16.8.0"},{"ref":"16.9.0"},{"ref":"16.9.1"},{"ref":"16.10.0"},{"ref":"16.11.0"},{"ref":"16.11.1"},{"ref":"16.12.0"},{"ref":"16.13.0"},{"ref":"16.13.1"},{"ref":"16.13.2"},{"ref":"16.14.0"},{"ref":"16.14.1"},{"ref":"16.14.2"},{"ref":"16.15.0"}]
```
