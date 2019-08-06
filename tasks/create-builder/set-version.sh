#!/usr/bin/env bash
set -eo pipefail

while getopts "v:" arg
do
    case $arg in
    v) version="${OPTARG}";;
    esac
done

if [[ -z "$version" ]]; then #version not provided, use latest git tag
    git_tag=$(git describe --abbrev=0 --tags)
    version=${git_tag:1}
fi

SOURCE="${BASH_SOURCE[0]}"
DIR="$(dirname $SOURCE)"
go run -ldflags="-X main.VersionString=${version}" "$DIR"/template.go


