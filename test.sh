#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

xcodebuild test \
  -project "Project Report Builder.xcodeproj" \
  -scheme "Project Report Builder" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \
  -parallel-testing-enabled NO \
  -skip-testing:'Project Report BuilderUITests/Project_Report_BuilderUITests/testLaunchPerformance' \
  "$@"
