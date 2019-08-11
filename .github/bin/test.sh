#!/usr/bin/env sh -ex

set -o pipefail
git submodule update -i
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -sdk "$SDK" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO clean test | xcpretty
