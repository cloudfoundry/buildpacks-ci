#! /usr/bin/env bash

git clone https://github.com/geramirez/concourse-filter
pushd concourse-filter
	go build
	exec &> >(./concourse-filter)
popd
