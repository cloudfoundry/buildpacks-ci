#!/bin/bash

# shellcheck disable=SC2046
docker run -it -v $(pwd):/app -w /app crystallang/crystal crystal spec --no-debug
