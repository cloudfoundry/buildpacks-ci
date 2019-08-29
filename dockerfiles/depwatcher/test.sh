#!/bin/bash

docker run -it -v $(pwd):/app -w /app crystallang/crystal crystal spec --no-debug
