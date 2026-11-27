#!/bin/bash
# 命令行构建脚本（模拟器）。
#
# 为什么需要 -Xfrontend -disable-sandbox：
#   在当前终端环境里 Swift 宏插件（swift-plugin-server）无法初始化自身的 sandbox，
#   会报 "external macro implementation ... produced malformed response"。
#   该 flag 只解除宏插件的沙箱，不改变编译产物行为。
#   在 Xcode 里直接 Run 构建不受影响，不需要这个参数。
#
# 用法：./scripts/build.sh [Debug|Release]

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-Debug}"

# 每次构建前重新生成工程，避免新增源文件没进 pbxproj 导致 "cannot find X in scope"。
# （只改代码不动目录结构时可加 SKIP_GEN=1 跳过，省几秒。）
if [ "${SKIP_GEN:-0}" != "1" ]; then
  xcodegen generate >/dev/null
fi

xcodebuild \
  -project LeitorQR.xcodeproj \
  -scheme LeitorQR \
  -configuration "$CONFIG" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
  build
