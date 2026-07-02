#!/bin/sh
set -euo pipefail

# Ensure each Xcode Cloud run gets a unique build number to satisfy App Store Connect.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${CI_BUILD_NUMBER}" "$CI_PRIMARY_REPOSITORY_PATH/MONTRA/Info.plist"
fi
