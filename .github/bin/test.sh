#!/user/bin/env sh -ex

xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -sdk "$SDK" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO clean test | xcpretty
