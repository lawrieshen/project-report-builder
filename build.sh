#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

xcodebuild build \
  -project "Project Report Builder.xcodeproj" \
  -scheme "Project Report Builder" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build
