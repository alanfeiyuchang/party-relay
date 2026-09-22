#!/usr/bin/env bash
# 录「点自选色 → 色盘从按钮展开 → 拖色相 → 收起缩回按钮」的完整动画
# 用法：scripts/record-colorpicker.sh   （不需要打开 Xcode，也不用手点模拟器）
# 产出：Screenshots/colorpicker/colorpicker.mp4（没有 ffmpeg 时是 .mov）+ colorpicker.png
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

# 动画要看清楚，关掉模拟器的「减弱动态效果」之类的干扰并保持满帧
xcrun simctl install "$UDID" build/Debug-iphonesimulator/PartyRelay.app
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

echo "▶ 录屏…"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/colorpicker.mov" &
REC=$!
sleep 1.5
SIMCTL_CHILD_SCREENSHOT_MODE=drawpicker SIMCTL_CHILD_SCREENSHOT_LANG=zh \
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
sleep 3                                   # 启动 + 1.2s 停顿 + 展开动画
xcrun simctl io "$UDID" screenshot "$OUT/colorpicker.png" >/dev/null   # 展开后的静态图
sleep 4                                   # 拖色相 + 收起动画
kill -INT "$REC"; wait "$REC" 2>/dev/null || true

# .mov 手机上也能放，但转成 mp4 更通用
if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -y -i "$OUT/colorpicker.mov" \
    -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$OUT/colorpicker.mp4"
  rm -f "$OUT/colorpicker.mov"
fi
echo "✅ 完成：$OUT"; ls -la "$OUT"
