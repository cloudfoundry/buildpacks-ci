# Building/Pushing

docker build -t cfbuildpacks/depwatcher .
docker push cfbuildpacks/depwatcher

# Example run

```
$ echo '{"source":{"type":"rlang","name":"r"}}' | crystal src/check.cr
{"source":{"type":"rlang","name":"r"}}
[{"ref":"3.2.4"},{"ref":"3.2.5"},{"ref":"3.3.0"},{"ref":"3.3.1"},{"ref":"3.3.2"},{"ref":"3.3.3"},{"ref":"3.4.0"},{"ref":"3.4.1"},{"ref":"3.4.2"},{"ref":"3.4.3"}]

$ echo '{"source":{"type":"rlang","name":"r"},"version":{"ref":"3.4.2"}}' | crystal src/in.cr -- /tmp
{"source":{"type":"rlang","name":"r"},"version":{"ref":"3.4.2"}}
{"ref":"3.4.2","url":"https://cran.cnr.berkeley.edu/src/base/R-3/R-3.4.2.tar.gz"}
{"version":{"ref":"3.4.2"}}
```
