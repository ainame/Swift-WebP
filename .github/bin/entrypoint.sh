#!/bin/bash -xe

REMOTE_REPO="https://${INPUT_GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/ainame/Swift-WebP.git"
git clone $REMOTE_REPO repo
cd repo
git fetch origin ${GITHUB_REF}:branch_for_test
git checkout branch_for_test

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
