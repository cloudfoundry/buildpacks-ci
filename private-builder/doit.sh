#! /usr/bin/env bash

ytt -f . > complete-builder-pipeline.yml && fly -t buildpacks sp -p cnb-builder -c complete-builder-pipeline.yml
