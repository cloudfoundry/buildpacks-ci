#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

set -x


echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
apt-key add buildpacks-ci/config/google-chrome-apt-key.pub

apt-get update
apt-get install libgconf-2-4 unzip google-chrome-stable -y

wget -O chromedriver.zip 'https://chromedriver.storage.googleapis.com/2.34/chromedriver_linux64.zip'
[ e42a55f9e28c3b545ef7c7727a2b4218c37489b4282e88903e4470e92bc1d967 = $(shasum -a 256 chromedriver.zip | cut -d' ' -f1) ]
unzip chromedriver.zip -d /usr/local/bin/
rm chromedriver.zip

cd buildpacks-site
yarn install --no-progress
yarn run unit
yarn run e2e
yarn run build
