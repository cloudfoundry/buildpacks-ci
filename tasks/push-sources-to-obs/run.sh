#!/bin/bash

# Setup .oscrc
sed -i "s|<username>|$OBS_USERNAME|g" /root/.oscrc
sed -i "s|<password>|$OBS_PASSWORD|g" /root/.oscrc

package_name=`ls source-artifacts -1 | head -n1`

if [ -z "$package_name" ]; then
  echo "No sources downloaded."
  exit 0
fi

package=buildpack-binary-$package_name

# Set up osc working directory
osc co -M $PROJECT

# Create package if it doesn't exist yet
pushd $PROJECT
osc mkpac $package
popd

# Add source artifacts
pushd $PROJECT/$package/
ln -s ../../source-artifacts/$package_name/* .
osc addremove
osc ci -m "Upload sources from latest build"
