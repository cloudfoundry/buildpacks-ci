set -ex

bundle exec rspec --tag ~fly
pushd dockerfiles/depwatcher
  shards
  crystal spec --no-debug
popd

bundle exec rake
