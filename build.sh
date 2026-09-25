#!/bin/bash
set -euo pipefail

# 切換到腳本所在的專案資料夾，從其他位置執行也能找到專案。
cd "$(dirname "$0")"

# 編譯開發用 App，不會自動開啟 App。
xcodebuild build \
  -project "Project Report Builder.xcodeproj" \
  -scheme "Project Report Builder" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \ 
  "$@"
