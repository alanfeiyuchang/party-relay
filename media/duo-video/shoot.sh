#!/usr/bin/env bash
# 把视频要用的 App 画面全部从模拟器拍一遍（Blender 贴图 + 宣传片里的手机画面）。
# 用法：media/duo-video/shoot.sh        产出都在 media/duo-video/tex/
#
# 外屏那几张要特别处理：真机摆成笔记本姿势时外屏是**横**的（官方模型 112.5×77.4mm，
# 长宽比 1.4535 ≈ 678:466），而模拟器只肯给竖着的 466×678。所以用 COVER_SIZE=678x466
# 让 App 按横版排一次、自己转 90° 塞进竖窗口，截完再 sips 转回来。
set -euo pipefail
cd "$(dirname "$0")/../.."

BUNDLE=com.partyrelay.app
TEX="media/duo-video/tex"
DUO=92C164C0-0875-4083-BD5D-F22D5B3E9653      # iPhone Duo
# 这台 Duo 模拟器的内屏（2007×2853）是黑的，App 实际画在外屏那块 1398×2034 上，
# 所以截图必须点名这个 display，否则默认截到的是一片全黑的内屏
DUO_DISPLAY=C3769B80-B5AC-4179-A4BD-B6F80439C846
mkdir -p "$TEX"

echo "▶ 编译（模拟器 Debug）…"
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay \
  -sdk iphonesimulator -configuration Debug -arch arm64 build \
  CODE_SIGNING_ALLOWED=NO SYMROOT=build -quiet

phone_udid() {
  xcrun simctl list devices available \
    | grep -m1 -E "iPhone 17 Pro \(iOS 27\) \(" | grep -oE "[0-9A-F-]{36}"
}
PHONE=$(phone_udid)

boot() {  # $1 udid
  xcrun simctl bootstatus "$1" -b >/dev/null 2>&1 || xcrun simctl boot "$1"
  xcrun simctl bootstatus "$1" -b >/dev/null
  xcrun simctl install "$1" build/Debug-iphonesimulator/PartyRelay.app
}

# shot <udid> <出图名> <转多少度(0/-90)> <环境变量…>；DISPLAY 为空则用默认 display
shot() {
  local udid=$1 name=$2 spin=$3; shift 3
  local env_args=() disp=()
  env_args+=("SIMCTL_CHILD_SCREENSHOT_LANG=zh")
  for kv in "$@"; do env_args+=("SIMCTL_CHILD_$kv"); done
  [[ -n "${DISPLAY_UUID:-}" ]] && disp=(--display "$DISPLAY_UUID")
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  env "${env_args[@]}" xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
  sleep 4
  xcrun simctl io "$udid" screenshot ${disp[@]+"${disp[@]}"} --type=png "$TEX/$name" >/dev/null
  [[ "$spin" != "0" ]] && sips -r "$spin" "$TEX/$name" >/dev/null
  printf '  %-22s %s\n' "$name" "$(sips -g pixelWidth -g pixelHeight "$TEX/$name" | tail -2 | tr -d ' \n')"
}

echo "▶ Duo 模拟器（外屏 + 笔记本模式内屏）…"
boot "$DUO"
DISPLAY_UUID=$DUO_DISPLAY
# 外屏三张：画板镜像 / 答对报分 / 换词。都按横版排，COVER_BORDER=0 去掉那圈验证用的红框
shot "$DUO" cover.png         -90 PREVIEW_COVER=1 COVER_MODE=drawing COVER_BORDER=0 COVER_SIZE=678x466
shot "$DUO" cover-correct.png -90 PREVIEW_COVER=1 COVER_MODE=drawing COVER_BORDER=0 COVER_SIZE=678x466 COVER_CELEBRATE=1
shot "$DUO" cover-skip.png    -90 PREVIEW_COVER=1 COVER_MODE=drawing COVER_BORDER=0 COVER_SIZE=678x466 COVER_CELEBRATE=skip
# 笔记本模式的内屏：上半屏词卡、下半屏画板，就是贴在两块内屏上的那张
shot "$DUO" inner.png           0 FORCE_LAPTOP=1 SKIP_CAMERA=1 SCREENSHOT_MODE=drawcanvas

python3 media/duo-video/fill_band.py "$TEX"/cover*.png

echo "▶ iPhone 17 Pro（普通竖屏，宣传片里手机画面用）…"
boot "$PHONE"
DISPLAY_UUID=
shot "$PHONE" app-menu.png  0 SKIP_CAMERA=1 SCREENSHOT_MODE=menu
shot "$PHONE" app-draw.png  0 SKIP_CAMERA=1 SCREENSHOT_MODE=drawcanvas
shot "$PHONE" app-word.png  0 SKIP_CAMERA=1 SCREENSHOT_MODE=draw
shot "$PHONE" app-home.png  0 SKIP_CAMERA=1 SCREENSHOT_MODE=home

echo "✓ 都在 $TEX/"
