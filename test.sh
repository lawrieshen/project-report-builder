#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 執行日常測試，跳過啟動效能測試。
# test 會自動編譯，不需要先執行 build.sh。
xcodebuild test \
  -project "Project Report Builder.xcodeproj" \
  -scheme "Project Report Builder" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \
  -parallel-testing-enabled NO \
  -skip-testing:'Project Report BuilderUITests/Project_Report_BuilderUITests/testLaunchPerformance'
