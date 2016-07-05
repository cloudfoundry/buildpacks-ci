#! /usr/bin/env bash

go install github.com/geramirez/concourse-filter
export CREDENTIAL_FILTER_WHITELIST=`env | cut -d '=' -f 1 | grep -v '^_$' | xargs echo | tr ' ' ','`
exec &> >($GOPATH/bin/concourse-filter)
