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
# 先空跑一次冷启动再杀掉：CI 上第一次启动要白屏好几秒，录的那次得是热启动，画面才会马上出来
SIMCTL_CHILD_SCREENSHOT_MODE=drawcanvas xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
sleep 8
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

echo "▶ 录屏…"
MOV="$OUT/colorpicker.mov"
RECLOG=$(mktemp)
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$MOV" >"$RECLOG" 2>&1 &
REC=$!
# recordVideo 在 CI 机器上要十几到二十几秒才真正开录；必须等它打出 Recording started 再启动 App，
# 不然 App 里那套展开/收起早就演完了，录下来只有静止的画布
for _ in $(seq 1 600); do
  grep -q "Recording started" "$RECLOG" && break
  kill -0 "$REC" 2>/dev/null || { cat "$RECLOG"; echo "✗ 录屏进程提前退出了"; exit 1; }
  sleep 0.2
done
grep -q "Recording started" "$RECLOG" || { cat "$RECLOG"; echo "✗ 等了 120 秒还没开录"; exit 1; }
sleep 1
SIMCTL_CHILD_SCREENSHOT_MODE=drawpicker SIMCTL_CHILD_SCREENSHOT_LANG=zh \
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
# App 里的时间线（DrawView drawpicker）：2.0s 展开 → 3.6s 点橙色格子 → 3.85s 自己收起
if command -v ffmpeg >/dev/null; then
  sleep 12      # 冷启动也留足余量，多录的部分后面会裁掉
else
  sleep 3.5     # 没有 ffmpeg 只能掐时间截图：大约是拖完色相、还没收起
  xcrun simctl io "$UDID" screenshot "$OUT/colorpicker.png" >/dev/null
  sleep 5
fi
kill -INT "$REC"; wait "$REC" 2>/dev/null || true
cat "$RECLOG"; rm -f "$RECLOG"

# 截图和视频都从录像里取，不再靠 sleep 掐点
if command -v ffmpeg >/dev/null; then
  # 裁掉顶部倒计时那一条（每秒都在变），剩下的画面里最后一次变化 = 收起动画结束
  LAST=$(ffmpeg -hide_banner -nostats -i "$MOV" \
      -vf "crop=iw:ih*0.84:0:ih*0.16,scale=160:-2,mpdecimate,showinfo" -f null - 2>&1 \
    | sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p' | tail -1)
  LAST=${LAST:-0}
  if awk "BEGIN{exit !($LAST < 5)}"; then
    echo "⚠ 录像里没找到选色框动画（最后一次画面变化在 ${LAST}s），保留整段录像，截图取最后一帧"
    SHOT=$LAST; START=0; DUR=600
  else
    SHOT=$(awk "BEGIN{print $LAST - 1.25}")                 # 拖完色相、还没收起：面板展开的静态图
    START=$(awk "BEGIN{s = $LAST - 6.5; print (s < 0 ? 0 : s)}")
    DUR=7.5
    echo "▶ 收起动画在 ${LAST}s 结束 → 截图取 ${SHOT}s，视频取 ${START}s 起 ${DUR}s"
  fi
  ffmpeg -loglevel error -y -ss "$SHOT" -i "$MOV" -frames:v 1 "$OUT/colorpicker.png"
  # .mov 手机上也能放，但转成 mp4 更通用
  ffmpeg -loglevel error -y -ss "$START" -t "$DUR" -i "$MOV" \
    -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$OUT/colorpicker.mp4"
  rm -f "$MOV"
fi
echo "✅ 完成：$OUT"; ls -la "$OUT"
