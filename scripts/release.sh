#!/bin/bash
# 真机 Release 构建 / Archive / 导出 IPA（上架管线）。
#
# Team ID 通过环境变量注入（不写进 project.yml，避免泄漏/误提交）：
#   export LEITORQR_TEAM_ID=ABCDEF1234   # ASC → Membership details → Team ID
#
# 用法：
#   ./scripts/release.sh build     # 真机 Release 构建（验证签名能过）
#   ./scripts/release.sh archive   # 出 .xcarchive
#   ./scripts/release.sh export    # 从 archive 导出 App Store IPA
#
# 前置（一次性）：
#   1. ASC 建立 App ID com.mg.localicard，勾选 Hotspot Configuration；
#   2. `xcodebuild -downloadAllPlatforms` 或让 -allowProvisioningUpdates 自动管理描述文件；
#   3. 上传走 Transporter / Xcode Organizer（IPA 在 .build/export/）。

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${LEITORQR_TEAM_ID:?先 export LEITORQR_TEAM_ID=<你的Team ID>，见脚本头部说明}"
CMD="${1:?用法: ./scripts/release.sh [build|archive|export]}"

# 每次出包前重新生成工程（entitlements / 设置改动生效）。
xcodegen generate >/dev/null

ARCHIVE=".build/archive/LeitorQR.xcarchive"
EXPORT_DIR=".build/export"

case "$CMD" in
  build)
    xcodebuild \
      -project LeitorQR.xcodeproj \
      -scheme LeitorQR \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -derivedDataPath .build/DerivedData \
      DEVELOPMENT_TEAM="$TEAM_ID" \
      -allowProvisioningUpdates \
      OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
      build
    echo "✅ 真机 Release 构建完成：.build/DerivedData/Build/Products/Release-iphoneos/LeitorQR.app"
    ;;
  archive)
    xcodebuild \
      -project LeitorQR.xcodeproj \
      -scheme LeitorQR \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -derivedDataPath .build/DerivedData \
      DEVELOPMENT_TEAM="$TEAM_ID" \
      -allowProvisioningUpdates \
      OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
      -archivePath "$ARCHIVE" \
      archive
    echo "✅ Archive 完成：$ARCHIVE"
    ;;
  export)
    [ -d "$ARCHIVE" ] || { echo "缺少 archive：先跑 ./scripts/release.sh archive" >&2; exit 1; }
    mkdir -p "$EXPORT_DIR"
    cat > "$EXPORT_DIR/exportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<true/>
</dict>
</plist>
PLIST
    xcodebuild \
      -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$EXPORT_DIR/exportOptions.plist" \
      -exportPath "$EXPORT_DIR" \
      -allowProvisioningUpdates
    echo "✅ IPA 导出完成：$EXPORT_DIR/LeitorQR.ipa（用 Transporter 或 Xcode Organizer 上传）"
    ;;
  *)
    echo "未知命令：$CMD（支持 build / archive / export）" >&2
    exit 1
    ;;
esac
