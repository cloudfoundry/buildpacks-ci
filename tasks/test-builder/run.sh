#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

./buildpacks-ci/scripts/start-docker

set -x

docker load -i builder-image/builder.tgz

pushd pack
    echo "Building pack..."
    go build -mod=vendor -o pack ./cmd/pack/main.go
popd

echo "Building test apps..."
for app_path in cnb-builder/fixtures/*; do
    ./pack/pack build "$(basename "$app_path")" --builder "$REPO:$STACK" -p "$app_path" --no-pull
done

if [ "$STACK" == "cflinuxfs3" ]; then
    for app_path in cnb-builder/fs3-fixtures/*; do
	./pack/pack build "$(basename "$app_path")" --builder "$REPO:$STACK" -p "$app_path" --no-pull
    done
fi


