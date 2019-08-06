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

go run -ldflags="-X main.VersionString=${version}" ./template.go


