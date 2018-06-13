# Depwatcher

A concourse resource to watch for new releases of dependencies.

The Buildpacks team use this to build new dependencies for buildpacks.

The various depwatchers in this resource (in `src`) are written in Crystal, as are the tests (in `spec`).

## Run unit tests

`crystal spec`

(you may need to install dependencies via `crystal deps` before running tests)

## Building/Pushing

`docker build -t cfbuildpacks/depwatcher .`

`docker push cfbuildpacks/depwatcher`

## Example run

```
$ echo '{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}' | crystal src/check.cr
  {"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"}}
  [{"ref":"1.0.0"},{"ref":"1.0.1"},{"ref":"2.0.0"}]
  
$ echo '{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"},"version":{"ref":"2.0.0"}}' | crystal src/in.cr -- /tmp
{"source":{"type":"github_releases","name":"hwc","repo":"cloudfoundry/hwc","extension":"exe"},"version":{"ref":"2.0.0"}}
{"ref":"2.0.0","url":"https://github.com/cloudfoundry/hwc/releases/download/2.0.0/hwc.exe","sha256":"1bad9c61262702404653f4d043d79082e8a181ee33e2c1e11db3eb346e7fcd33"}
{"version":{"ref":"2.0.0"}}
```