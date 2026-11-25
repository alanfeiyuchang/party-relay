#!/usr/bin/env bash
# 在模拟器里录下 App 内实时渲染的小红书宣传片，裁成竖版成片。
#
#   scripts/record-trailer.sh                 录 9:16（默认）
#   scripts/record-trailer.sh --aspect 3x4    录 3:4
#   scripts/record-trailer.sh --probe 35 6    只看第 35 秒起的 6 秒（抽查用，出一张拼图）
#   scripts/record-trailer.sh --cover         只出小红书封面 out/cover.png（1080×1440）
#
# 片子本身是 PartyRelay/Trailer/ 下那套 SwiftUI，`-ML_trailer YES` 启动时顶掉正常界面。
# 画面里用到的图（模拟器实拍 + Blender 渲染）不在 App 包里，装好之后由这个脚本
# 拷进 Documents/trailer/，见 media/duo-video/shoot.sh。
#
# 对时间：开场 5 秒是**纯黑**板，脚本用 blackdetect 找到它结束的位置，从那儿精确裁
# DURATION 秒。模板里用的是白板，但这支片子底色是浅的（奶油紫），白板跟正片分不开。
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=com.partyrelay.app
DURATION=101.5           # 和 TrailerCanvas.duration、voiceover.srt 最后一条一致
LEAD_IN=5.0           # 和 TrailerCanvas.leadIn 一致
ASPECT=9x16
OUT=out
PROBE_FROM=""
PROBE_SECS=6

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aspect) ASPECT=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --device) DEVICE=$2; shift 2 ;;
    --probe) PROBE_FROM=$2; PROBE_SECS=${3:-6}; shift 3 || shift 2 ;;
    --cover) COVER=1; shift ;;
    *) echo "不认识的参数：$1" >&2; exit 2 ;;
  esac
done

command -v ffmpeg >/dev/null || { echo "缺 ffmpeg：brew install ffmpeg" >&2; exit 1; }

UDID=${DEVICE:-$(xcrun simctl list devices available \
  | grep -m1 -E "iPhone 17 Pro \(iOS 27\) \(" | grep -oE "[0-9A-F-]{36}")}
[[ -n "$UDID" ]] || { echo "找不到 iPhone 17 Pro (iOS 27) 模拟器" >&2; exit 1; }

echo "▶ 构建（Release，模拟器）…"
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay \
  -sdk iphonesimulator -configuration Release -arch arm64 build \
  CODE_SIGNING_ALLOWED=NO SYMROOT=build -quiet \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) TRAILER' 

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" build/Release-iphonesimulator/PartyRelay.app

echo "▶ 送素材进 Documents/trailer/ …"
DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
DEST="$DATA/Documents/trailer"
mkdir -p "$DEST"
# 第三个参数是长边上限：片子里这些图最多也就铺 390pt 宽，原图扔进去只是白白多解一堆像素
copy() {
  if [[ -f "$1" ]]; then
    cp "$1" "$DEST/$2"
    if [[ -n "${3:-}" ]]; then sips -Z "$3" "$DEST/$2" >/dev/null; fi
  else
    echo "  ⚠ 缺素材 $1（画面上会是占位框）"
  fi
}
copy media/duo-video/render/wide.png   3d-wide.png
copy media/duo-video/render/inner.png  3d-inner.png
copy media/duo-video/render/cover.png  3d-cover.png
for f in cover cover-correct cover-skip; do
  copy "media/duo-video/tex/$f.png" "$f.png" 900
done
copy media/duo-video/tex/inner.png     inner.png     900
for f in app-menu app-draw app-word app-home; do
  copy "media/duo-video/tex/$f.png" "$f.png" 900
done
copy PartyRelay/Assets.xcassets/AppIcon.appiconset/AppIcon.png icon.png 320

if [[ -n "${COVER:-}" ]]; then
  mkdir -p "$OUT"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -ML_trailerCover YES >/dev/null
  sleep 5
  SHOT="$OUT/cover-raw.png"
  xcrun simctl io "$UDID" screenshot --type=png "$SHOT" >/dev/null
  # 屏幕是 1206×2622，封面那块 3:4 卡片居中铺满宽度：裁 1206×1608 再缩到 1080×1440
  ffmpeg -hide_banner -loglevel error -y -i "$SHOT" \
    -vf "crop=1206:1608:0:(ih-1608)/2,scale=1080:1440:flags=lanczos" "$OUT/cover.png"
  rm -f "$SHOT"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  echo "✓ $OUT/cover.png"
  exit 0
fi

DIR="$OUT/$ASPECT"
mkdir -p "$DIR"
RAW="$DIR/raw.mov"

LAUNCH_ARGS=(-ML_trailer YES -ML_trailerAspect "$ASPECT")
if [[ -n "$PROBE_FROM" ]]; then
  # 抽查：直接从某一秒开播（跳过黑板），录一小段拼成一张图
  LAUNCH_ARGS+=(-ML_trailerFrom "$PROBE_FROM")
  RECORD_SECONDS=$(python3 -c "print(int($PROBE_SECS + 4))")
else
  RECORD_SECONDS=$(python3 -c "print(int($LEAD_IN + $DURATION + 7))")
fi

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
sleep 1

echo "▶ 录屏 ${RECORD_SECONDS}s（期间别动模拟器窗口）…"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$RAW" >/dev/null 2>&1 &
REC=$!
sleep 6      # recordVideo 要几秒才真的开录，启动早了会丢开头
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${LAUNCH_ARGS[@]}" >/dev/null
sleep "$RECORD_SECONDS"
kill -INT "$REC" 2>/dev/null || true
wait "$REC" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

IFS=, read -r IW IH < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
  -of csv=p=0 "$RAW")
# 画布 390pt 宽按屏幕宽缩放，所以裁出来就是「整宽 × 对应高」，上下居中
RATIO=$(python3 -c "print(16/9 if '$ASPECT' == '9x16' else 4/3)")
read -r CW CH CX CY OW OH < <(python3 -c "
iw, ih, r = $IW, $IH, $RATIO
cw = iw - (iw % 2); ch = int(round(r * iw)); ch -= ch % 2
cy = max(0, (ih - ch) // 2); cy -= cy % 2
ow = 1080; oh = int(round(1080 * r)); oh -= oh % 2
print(cw, ch, 0, cy, ow, oh)")
CROP="$CW:$CH:$CX:$CY"

if [[ -n "$PROBE_FROM" ]]; then
  SHEET="$DIR/probe-sheet.png"
  # 录像开头有几秒是模拟器桌面（recordVideo 要先热起来），从 App 真正出画的地方开始取
  ffmpeg -hide_banner -loglevel error -y -i "$RAW" -ss 7 -t "$PROBE_SECS" \
    -vf "crop=$CROP,fps=2,scale=240:-2,tile=5x4" -frames:v 1 "$SHEET"
  echo "✓ 抽查拼图：$SHEET（第 $PROBE_FROM 秒起 ${PROBE_SECS}s，每秒 2 帧）"
  exit 0
fi

echo "▶ 找开场黑板的结束位置…"
# 黑板是全片唯一一段纯黑，blackdetect 的第一段结束处就是 t = 0
BLACK=$(ffmpeg -hide_banner -nostats -i "$RAW" -t 25 \
  -vf "crop=$CROP,scale=$((OW / 2)):$((OH / 2)),blackdetect=d=0.8:pix_th=0.06:pic_th=0.98" \
  -f null - 2>&1 | grep -m1 -oE "black_end:[0-9.]+" | cut -d: -f2 || true)
if [[ -z "$BLACK" ]]; then
  ffmpeg -hide_banner -loglevel error -y -ss 5 -i "$RAW" -frames:v 1 -vf "crop=$CROP" \
    "$DIR/debug-first-frame.png" || true
  echo "✗ 没找到开场黑板：这次启动多半不是从头播的（上一次的实例没退干净，或者模拟器太卡）。" >&2
  echo "  看一眼 $DIR/debug-first-frame.png，然后 xcrun simctl shutdown all 再跑一次。" >&2
  exit 1
fi
echo "  黑板结束于 ${BLACK}s"

echo "▶ 裁成片（${DURATION}s，60fps，${OW}×${OH}）…"
ffmpeg -hide_banner -loglevel error -y -i "$RAW" -ss "$BLACK" -t "$DURATION" -an \
  -vf "crop=$CROP,scale=$OW:$OH:flags=lanczos,fps=60,format=yuv420p" \
  -c:v libx264 -preset slow -crf 18 -movflags +faststart "$DIR/trailer.mp4"

mkdir -p "$DIR/frames"
KEYS=$(python3 -c "print(max(1, round($DURATION / 5)))")
for i in $(seq 1 "$KEYS"); do
  T=$(python3 -c "print(($i - 0.5) * $DURATION / $KEYS)")
  ffmpeg -hide_banner -loglevel error -y -i "$DIR/trailer.mp4" -ss "$T" -frames:v 1 \
    "$(printf '%s/frames/frame-%02d.png' "$DIR" "$i")"
done
cp trailer/voiceover.srt "$DIR/voiceover.srt" 2>/dev/null || true
# 原始录像留着：对时间对不上的时候可以不重录，直接换个起点重裁

echo "✓ $DIR/trailer.mp4"
ffprobe -v error -show_entries format=duration -show_entries stream=width,height,r_frame_rate \
  -of default=nw=1 "$DIR/trailer.mp4"
