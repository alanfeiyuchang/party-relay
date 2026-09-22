#!/usr/bin/env bash
# 录「画布 → 弹出选色框」的动画：编译 → 启动模拟器 → 录屏 → 截图 → 转 GIF
# 用法：scripts/record-colorpicker.sh   （不需要打开 Xcode，也不用手点模拟器）
# 产出：Screenshots/colorpicker/{colorpicker.mov, colorpicker.png, colorpicker.gif(有 ffmpeg 时)}
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=com.partyrelay.app
OUT=Screenshots/colorpicker
mkdir -p "$OUT"

echo "▶ 编译（模拟器 Debug）…"
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay \
  -sdk iphonesimulator -configuration Debug -arch arm64 build \
  CODE_SIGNING_ALLOWED=NO SYMROOT=build -quiet

# 已经开着的 iPhone 模拟器优先，否则挑一台可用的 iPhone Pro
UDID=$(xcrun simctl list devices booted | grep -m1 -E "iPhone" | grep -oE "[0-9A-F-]{36}" || true)
if [[ -z "$UDID" ]]; then
  UDID=$(xcrun simctl list devices available | grep -m1 -E "iPhone [0-9]+ Pro \(" | grep -oE "[0-9A-F-]{36}")
  echo "▶ 启动模拟器 $UDID …"
  xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcrun simctl install "$UDID" build/Debug-iphonesimulator/PartyRelay.app
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

echo "▶ 录屏…"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/colorpicker.mov" &
REC=$!
sleep 1.5
SIMCTL_CHILD_SCREENSHOT_MODE=drawpicker SIMCTL_CHILD_SCREENSHOT_LANG=zh \
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
sleep 5            # 启动 + 1 秒停顿 + 选色框弹出动画
xcrun simctl io "$UDID" screenshot "$OUT/colorpicker.png" >/dev/null
sleep 1
kill -INT "$REC"; wait "$REC" 2>/dev/null || true

if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -y -i "$OUT/colorpicker.mov" \
    -vf "fps=20,scale=390:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
    "$OUT/colorpicker.gif"
fi
echo "✅ 完成：$OUT"; ls -la "$OUT"
