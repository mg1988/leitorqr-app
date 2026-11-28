#!/bin/bash
# 录一条 App Review 用的演示视频（模拟器）。
#
# 局限（转述时务必如实说明，别把模拟器录像当成"真机演示"）：
#   - 模拟器没有摄像头 → 取景画面是 App 内部画的假背景（LEITORQR_FAKE_CAMERA）
#   - 跑不起 NEHotspotConfiguration → Wi-Fi 只到结果页，不会真的连上网络
#   - 相册走的是调试种子数据
# 所以本视频能证明"界面与流程存在、状态变化真实"，证不了"相机能扫码 / Wi-Fi 能连"。
#
# 用法： ./scripts/record_demo.sh [输出路径]
# 产物： store/review/demo.mp4（720 宽，H.264，带英文字幕，无声）
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${LEITORQR_DEVICE:-booted}"
BUNDLE="com.mg.localicard"
APP=".build/DerivedData/Build/Products/Debug-iphonesimulator/LeitorQR.app"
RAW=".build/demo_raw"
OUTDIR="store/review"
OUT="${1:-$OUTDIR/demo.mp4}"
TITLE_SEC=2.6
FONT="/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# 系统 python3 没有 imageio_ffmpeg，用 WorkBuddy 自带的 venv（可用 PY 覆盖）
PY="${PY:-/Users/genweimi/.workbuddy/binaries/python/envs/default/bin/python3}"
[ -x "$PY" ] || PY=python3
"$PY" -c "import imageio_ffmpeg" 2>/dev/null || { echo "缺 imageio_ffmpeg（可用 PY=... 指定解释器）" >&2; exit 1; }
FF=$("$PY" -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")

[ -d "$APP" ] || { echo "缺少 Debug 构建产物，先跑 ./scripts/build.sh Debug" >&2; exit 1; }
mkdir -p "$RAW" "$OUTDIR"

# simctl 只在画面变化时出帧；ffmpeg -i 没有输出文件必然返回 1，pipefail 下要 || true
measure() {
  "$FF" -hide_banner -i "$1" 2>&1 | "$PY" -c "
import sys, re
m = re.search(r'Duration: (\\d+):(\\d+):([\\d.]+)', sys.stdin.read())
print('%.3f' % (float(m.group(1))*3600 + float(m.group(2))*60 + float(m.group(3))) if m else '0')
" || true
}

# 从启动开始录：能看到「取景页 → 结果面板弹出」的动效，但开头带 1 秒桌面 + 约 3 秒启动屏，
# 剪辑时用亮度找内容起点（取景页深色，启动屏纯白）。
record_launch() {
  local name="$1" secs="$2"; shift 2
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl install "$DEVICE" "$APP"
  rm -f "$RAW/$name.mp4"
  xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$RAW/$name.mp4" >/dev/null 2>&1 &
  local recpid=$!
  sleep 1.2
  env "$@" xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
  sleep "$secs"
  kill -INT "$recpid" 2>/dev/null || true
  wait "$recpid" 2>/dev/null || true
  echo "  录好 ${name}（$(du -h "$RAW/$name.mp4" | cut -f1)）"
}

# 先启动等稳定，再录：完全没有启动屏，适合静态页
record_static() {
  local name="$1" secs="$2"; shift 2
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl install "$DEVICE" "$APP"
  env "$@" xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
  sleep 6
  rm -f "$RAW/$name.mp4"
  xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$RAW/$name.mp4" >/dev/null 2>&1 &
  local recpid=$!
  sleep "$secs"
  kill -INT "$recpid" 2>/dev/null || true
  wait "$recpid" 2>/dev/null || true
  echo "  录好 ${name}（$(du -h "$RAW/$name.mp4" | cut -f1)）"
}

if [ "${SKIP_RECORD:-0}" = "1" ]; then
  echo "  跳过录制，复用 .build/demo_raw 里的原片"
else
if [ "${SKIP_RECORD:-0}" = "1" ]; then
  echo "  跳过录制，复用 .build/demo_raw 里的原片"
else
echo "== 1/5 启动 → 取景页 → 扫到 Wi-Fi 码 → 结果面板"
record_launch scan 15 \
  SIMCTL_CHILD_LEITORQR_LANGUAGE=en \
  SIMCTL_CHILD_LEITORQR_FAKE_CAMERA=1 \
  SIMCTL_CHILD_LEITORQR_FORCE_SCANNER_UI=1 \
  SIMCTL_CHILD_LEITORQR_SHEET_LARGE=1 \
  SIMCTL_CHILD_LEITORQR_FORCE_PREMIUM=1 \
  "SIMCTL_CHILD_LEITORQR_SIMULATE_SCAN=WIFI:T:WPA;S:Cafe Central;P:cafe2026;;"

echo "== 2/5 可疑链接的判定"
record_launch risk 13 \
  SIMCTL_CHILD_LEITORQR_LANGUAGE=en \
  SIMCTL_CHILD_LEITORQR_FAKE_CAMERA=1 \
  SIMCTL_CHILD_LEITORQR_FORCE_SCANNER_UI=1 \
  SIMCTL_CHILD_LEITORQR_SHEET_LARGE=1 \
  SIMCTL_CHILD_LEITORQR_FORCE_PREMIUM=1 \
  "SIMCTL_CHILD_LEITORQR_SIMULATE_SCAN=http://192.168.0.1/banco/login"

echo "== 3/5 创建自己的码"
record_launch create 15 \
  SIMCTL_CHILD_LEITORQR_LANGUAGE=en \
  SIMCTL_CHILD_LEITORQR_START_TAB=create \
  SIMCTL_CHILD_LEITORQR_CREATE_TYPE=wifi \
  "SIMCTL_CHILD_LEITORQR_PREFILL_GENERATOR=Cafe Central|cafe2026" \
  "SIMCTL_CHILD_LEITORQR_STYLE_PRESET=circle|true|1B2A4A|F7F3EA" \
  SIMCTL_CHILD_LEITORQR_AUTOSAVE_HISTORY=1 \
  SIMCTL_CHILD_LEITORQR_FORCE_PREMIUM=1

echo "== 4/5 本地历史"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
record_launch history 14 \
  SIMCTL_CHILD_LEITORQR_LANGUAGE=en \
  SIMCTL_CHILD_LEITORQR_START_TAB=history \
  SIMCTL_CHILD_LEITORQR_SEED_HISTORY=1 \
  SIMCTL_CHILD_LEITORQR_SEED_HISTORY_COUNT=6 \
  SIMCTL_CHILD_LEITORQR_FORCE_PREMIUM=1

echo "== 5/5 设置 / 买断入口"
record_launch settings 14 \
  SIMCTL_CHILD_LEITORQR_LANGUAGE=en \
  SIMCTL_CHILD_LEITORQR_START_TAB=settings \
  SIMCTL_CHILD_LEITORQR_HIDE_PRICE=1

fi

fi

echo "== 剪辑"

# 深色取景页片段：连续白帧（启动屏）之后第一次变暗 = 内容起点
content_start() {
  rm -rf "$RAW/fr" && mkdir -p "$RAW/fr"
  "$FF" -hide_banner -loglevel error -y -i "$1" -vf "fps=6,scale=90:-1" "$RAW/fr/%03d.png" || true
  "$PY" - "$RAW/fr" <<'PYEOF' || echo 0
import sys, glob
from PIL import Image, ImageChops, ImageStat, ImageStat
files = sorted(glob.glob(sys.argv[1] + "/*.png"))
if len(files) < 8:
    print("0"); raise SystemExit
def load(i):
    return Image.open(files[i]).convert("L")
# 录制从启动前 1.2 秒开始：2.5 秒处一定还停在启动屏上
ref = load(min(int(2.5 * 6), len(files) - 1))
start_i = min(int(2.5 * 6), len(files) - 1)
for i in range(start_i + 1, len(files)):
    im = load(i)
    diff = ImageStat.Stat(ImageChops.difference(im, ref)).sum[0]
    luma = ImageStat.Stat(im).mean[0]
    if diff > 8000 or luma < 200:      # 画面明显变化 或 变成深色（取景页）
        print("%.2f" % (i / 6.0)); break
else:
    print("0")
PYEOF
}

NAMES=(scan risk create history settings)
TARGETS=(6.0 4.8 4.0 3.6 3.6)
SEGS=()
DURS=()
for i in "${!NAMES[@]}"; do
  n="${NAMES[$i]}"
  tgt_dur="${TARGETS[$i]}"
  d=$(measure "$RAW/$n.mp4")
  start=$(content_start "$RAW/$n.mp4")
  start=$("$PY" -c "print(max(0.0, $start - 0.35))")
  tgt="$RAW/seg_$n.mp4"
  # tpad 把"画面静止、没有新帧"的那几秒用末帧补上，最后统一裁到目标时长
  "$FF" -hide_banner -loglevel error -y -ss "$start" -i "$RAW/$n.mp4" \
    -vf "scale=720:-2:flags=lanczos,fps=30,setsar=1,tpad=stop_mode=clone:stop_duration=10" \
    -t "$tgt_dur" -c:v libx264 -crf 20 -pix_fmt yuv420p -an "$tgt"
  SEGS+=("$tgt")
  DURS+=("$(measure "$tgt")")
  echo "  $n: 原 ${d}s，从 ${start}s 起，出 ${tgt_dur}s"
done

# 真机录屏放最前面：审核员最先想看的是"相机真的能读"。素材由用户真机录制，
# 后面一段会自己跳 Safari（点 Open in Browser 之后），所以只取前 4.6 秒。
REAL_SRC="store/review/real_scan.mp4"
if [ -f "$REAL_SRC" ]; then
  # 原片里"真实取景画面"只有开头约 1.2 秒，而且现场很暗、二维码几乎看不清。
  # 做法：这 1.2 秒放慢到 2.2 倍 + 轻微提亮（只调亮度对比，不改内容），
  # 后面的结果页保持原速。原片 5 秒后会自己跳到 Safari，所以第 2 段只留到 4.2 秒。
  SCALE="scale=720:1566:force_original_aspect_ratio=decrease,pad=720:1566:(ow-iw)/2:(oh-ih)/2:black"
  "$FF" -hide_banner -loglevel error -y -ss 0 -t 1.2 -i "$REAL_SRC" \
    -vf "$SCALE,eq=brightness=0.10:contrast=1.08,setpts=2.2*PTS,fps=30,setsar=1,format=yuv420p" \
    -c:v libx264 -crf 20 -an "$RAW/seg_real_a.mp4"
  "$FF" -hide_banner -loglevel error -y -ss 1.2 -t 2.8 -i "$REAL_SRC" \
    -vf "$SCALE,fps=30,setsar=1,format=yuv420p" \
    -c:v libx264 -crf 20 -an "$RAW/seg_real_b.mp4"
  printf "file '%s'\nfile '%s'\n" "$PWD/$RAW/seg_real_a.mp4" "$PWD/$RAW/seg_real_b.mp4" > "$RAW/list_real.txt"
  "$FF" -hide_banner -loglevel error -y -f concat -safe 0 -i "$RAW/list_real.txt" -c copy "$RAW/seg_real.mp4"
  SEGS=("$RAW/seg_real.mp4" ${SEGS[@]+"${SEGS[@]}"})
  DURS=("$(measure "$RAW/seg_real.mp4")" ${DURS[@]+"${DURS[@]}"})
  echo "  real: 真机录屏（取景放慢 2.2x + 结果页原速）$(measure "$RAW/seg_real.mp4")s"
fi

# 片头
"$FF" -hide_banner -loglevel error -y -f lavfi -i "color=c=0x0E1526:s=720x1566:d=$TITLE_SEC" \
  -vf "drawtext=fontfile='$FONT':text='Leitor QR':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=h/2-150,\
drawtext=fontfile='$FONT':text='App Review demo':fontcolor=0x93A7CC:fontsize=34:x=(w-text_w)/2:y=h/2-50" \
  -r 30 -c:v libx264 -crf 20 -pix_fmt yuv420p -an "$RAW/seg_title.mp4"

: > "$RAW/list.txt"
echo "file '$PWD/$RAW/seg_title.mp4'" >> "$RAW/list.txt"
for f in "${SEGS[@]}"; do echo "file '$PWD/$f'" >> "$RAW/list.txt"; done
"$FF" -hide_banner -loglevel error -y -f concat -safe 0 -i "$RAW/list.txt" -c copy "$RAW/joined.mp4"

# 字幕：按实际时长累加时间轴
CAPS=()
[ -f "$REAL_SRC" ] && CAPS+=("Real device: the camera reads a code")
CAPS+=("Wi-Fi codes: join the network with one tap")
CAPS+=("Links are checked on-device before you open them")
CAPS+=("Create your own codes: colors, dots, eyes, logo")
CAPS+=("History stays on the device, with search")
CAPS+=("One-time purchase. No subscription.")

"$PY" - "$RAW/subs.ass" "$TITLE_SEC" "${DURS[@]}" "@@@" "${CAPS[@]}" <<'PYEOF'
import sys
path, title = sys.argv[1], float(sys.argv[2])
rest = sys.argv[3:]
cut = rest.index("@@@")
durs = [float(x) for x in rest[:cut]]
caps = rest[cut + 1:]
head = """[Script Info]
ScriptType: v4.00+
PlayResX: 720
PlayResY: 1566
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,Arial,30,&H00FFFFFF,&H00FFFFFF,&H00101828,&H96101828,-1,0,0,0,100,100,0,0,3,10,0,2,40,40,56,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
def ts(t):
    h = int(t // 3600); m = int(t % 3600 // 60); s = t % 60
    return "%d:%02d:%05.2f" % (h, m, s)
lines = [head]
t = title
for c, d in zip(caps, durs):
    lines.append("Dialogue: 0,%s,%s,Cap,,0,0,0,,%s\n" % (ts(t + 0.3), ts(t + d - 0.3), c))
    t += d
open(path, "w").write("".join(lines))
print("字幕 %d 条，总时长 %.1fs" % (len(caps), t))
PYEOF

"$FF" -hide_banner -loglevel error -y -i "$RAW/joined.mp4" \
  -vf "subtitles='$RAW/subs.ass':fontsdir=/System/Library/Fonts/Supplemental" \
  -c:v libx264 -crf 22 -pix_fmt yuv420p -movflags +faststart -an "$OUT"

echo
echo "完成：$OUT"
"$FF" -hide_banner -i "$OUT" 2>&1 | grep -E "Duration|Stream" || true
ls -lh "$OUT" | awk '{print $5}'
