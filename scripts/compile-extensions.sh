#!/bin/bash

set -e

cd compile-extensions
bundle
bundle exec rspec
