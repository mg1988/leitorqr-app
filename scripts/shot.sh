#!/bin/bash
# 模拟器截图辅助脚本（仅开发期使用）。
#
# 用法：
#   ./scripts/shot.sh <输出名> [env=value ...] [--tab <tab>]
#
# 例：
#   ./scripts/shot.sh scan --env LEITORQR_FAKE_CAMERA=1
#   ./scripts/shot.sh history --tab history
#
# ASC 要求 6.9" 套图（1320×2868）。启动对应模拟器再截图：
#   xcrun simctl boot "iPhone 16 Pro Max"     # 或 iPhone 17 Pro Max
#   open -a Simulator
# 默认只对非 6.9" 尺寸给警告；设 LEITORQR_STRICT_69=1 则直接报错退出。
#
# 注意：simctl 启动不会加载 StoreKit 配置文件，价格类界面会显示"信息暂不可用"，
# 要看真实价格必须在 Xcode 里 Run。

set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${LEITORQR_DEVICE:-booted}"
CONFIG="${LEITORQR_CONFIG:-Debug}"
# 冷启动到可截图要 10–13 秒；清库重装后要 18–20 秒，可用 LEITORQR_SHOT_DELAY 覆盖。
DELAY="${LEITORQR_SHOT_DELAY:-10}"
BUNDLE="com.mg.localicard"
APP=".build/DerivedData/Build/Products/${CONFIG}-iphonesimulator/LeitorQR.app"
OUT="${1:?需要输出名}"
shift

[ -d "$APP" ] || { echo "缺少构建产物：$APP（先跑 ./scripts/build.sh $CONFIG）" >&2; exit 1; }
mkdir -p .build/shots
xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" "$APP"

ENVS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tab) ENVS+=("SIMCTL_CHILD_LEITORQR_START_TAB=$2"); shift 2 ;;
    --env) ENVS+=("SIMCTL_CHILD_${2%%=*}=${2#*=}"); shift 2 ;;
    *) echo "无法识别的参数：$1" >&2; exit 1 ;;
  esac
done

env ${ENVS[@]+"${ENVS[@]}"} xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null

# 转场与首帧渲染大约要 8–10 秒，早了会截到启动屏。
sleep "$DELAY"
SHOT=".build/shots/${OUT}.png"
xcrun simctl io "$DEVICE" screenshot "$SHOT" >/dev/null 2>&1

# 截图尺寸核对：ASC 主套图必须是 6.9"（1320×2868），旧 6.3"/6.1" 只能作附加套图。
if command -v sips >/dev/null 2>&1; then
  DIM=$(sips -g pixelWidth -g pixelHeight "$SHOT" 2>/dev/null | awk '/pixel/{print $2}' | paste -sd 'x' -)
  case "$DIM" in
    1320x2868|1290x2796) ;;
    *)
      MSG="⚠️  截图尺寸 ${DIM} 不是 6.9\"（1320x2868/1290x2796），ASC 主套图不收。先 xcrun simctl boot \"iPhone 16 Pro Max\"。"
      if [ "${LEITORQR_STRICT_69:-0}" = "1" ]; then echo "$MSG" >&2; exit 1; else echo "$MSG" >&2; fi
      ;;
  esac
fi

echo "$SHOT"
