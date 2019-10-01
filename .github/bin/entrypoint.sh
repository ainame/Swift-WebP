#!/bin/bash -xe

REMOTE_REPO="https://${INPUT_GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/ainame/Swift-WebP.git"
git clone $REMOTE_REPO repo
cd repo
git checkout -b ${INPUT_GITHUB_BRANCH} origin/${INPUT_GITHUB_BRANCH}

apt-get update
apt-get -q install -y build-essential autoconf automake libtool

git submodule update -i
cd libwebp
./autogen.sh
./configure
make
make install
cd ../
ldconfig

swift test --enable-test-discovery --verbose
