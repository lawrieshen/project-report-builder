#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 使用 Release 版本，單獨執行三輪啟動效能測試。
# 測試期間請勿操作 App，並保持資料內容一致。
# 此腳本不會封裝、上架或發布 App。
xcodebuild test \
  -project "Project Report Builder.xcodeproj" \
  -scheme "Project Report Builder" \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \
  -parallel-testing-enabled NO \
  -only-testing:'Project Report BuilderUITests/Project_Report_BuilderUITests/testLaunchPerformance' \
  -test-iterations 3
