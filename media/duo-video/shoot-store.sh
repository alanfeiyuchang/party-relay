#!/usr/bin/env bash
# 拍商店截图要用的那两张贴图（内屏笔记本姿态 + 外屏），中英各一套。
#
#   media/duo-video/shoot-store.sh zh    → media/duo-video/tex/
#   media/duo-video/shoot-store.sh en    → media/duo-video/tex-en/
#
# 和 shoot.sh 的区别，三条都是踩出来的：
#   1. 内屏按**真机实测**的几何排：竖版 669×951，安全区 top82/bottom34。
#      shoot.sh 那版是在 FoldPreview 之前写的，拍的其实是外屏那块 382×644。
#   2. 外屏的计时钉死在 42（COVER_REMAINING）。默认会一秒一跳倒数到 0，
#      截到 0 就成了「这局已经结束」，放进商店截图里很怪。
#   3. 截完要把模拟器的**摄像头挖孔**涂掉——那是宿主机屏幕上的黑点，
#      会被一起拍进贴图、再贴到 3D 模型的屏幕上。
set -euo pipefail
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

LANG_CODE=${1:-zh}
TEX="media/duo-video/tex"; [[ "$LANG_CODE" == "en" ]] && TEX="media/duo-video/tex-en"
BUNDLE=com.partyrelay.app
mkdir -p "$TEX"

echo "▶ 编译（模拟器 Debug）…"
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay -sdk iphonesimulator \
  -configuration Debug -arch arm64 build CODE_SIGNING_ALLOWED=NO SYMROOT=build -quiet 2>/dev/null || true

# 按机型找 Duo（改过名也认得），不按显示名
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
for rt,devs in json.load(sys.stdin)["devices"].items():
    for v in devs:
        if "iPhone-Duo" in v.get("deviceTypeIdentifier","") and v["state"]=="Booted":
            print(v["udid"]); break' | head -1)
[[ -n "$UDID" ]] || { echo "没有已启动的 iPhone Duo 模拟器" >&2; exit 1; }
xcrun simctl install "$UDID" build/Debug-iphonesimulator/PartyRelay.app

luma(){ ffmpeg -hide_banner -loglevel error -i "$1" -vf scale=1:1 -f rawvideo -pix_fmt gray - 2>/dev/null | od -An -tu1 | tr -d ' \n'; }

# 挑那块**亮着的**外屏：两台 Duo 上 display 号不一样，闭合时内屏是黑的
shot(){ local out=$1 crop=$2; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true; sleep 0.8
  env "$@" "SIMCTL_CHILD_SCREENSHOT_LANG=$LANG_CODE" xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep 7
  local d found=""
  for d in 1 3 0 2 4; do
    xcrun simctl io "$UDID" screenshot --display $d /tmp/_st.png >/dev/null 2>&1 || continue
    g=$(sips -g pixelWidth -g pixelHeight /tmp/_st.png | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')
    case "$g" in 1398x2034|2034x1398) ;; *) continue ;; esac
    [[ "$(luma /tmp/_st.png)" -le 6 ]] && continue
    found=$d; break
  done
  [[ -n "$found" ]] || { echo "  ✗ $out：找不到亮着的外屏" >&2; exit 1; }
  cp /tmp/_st.png "$TEX/$out"
  [[ "$crop" != "-" ]] && { ffmpeg -hide_banner -loglevel error -y -i "$TEX/$out" -vf "crop=$crop" /tmp/_sc.png; mv /tmp/_sc.png "$TEX/$out"; }
  printf '  %-18s %s\n' "$out" "$(sips -g pixelWidth -g pixelHeight "$TEX/$out" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')"
}

echo "▶ 内屏（笔记本姿态，669×951 竖版）"
# FoldPreview 把 669×951 按 0.6965 缩进 466×678 的宿主屏、上下各留 7.8pt → 裁掉留白
shot inner.png "1398:1988:0:23" \
  SIMCTL_CHILD_FOLD_SIZE=669x951 SIMCTL_CHILD_FOLD_INSETS=82,0,34,0 \
  SIMCTL_CHILD_FORCE_LAPTOP=1 SIMCTL_CHILD_SKIP_CAMERA=1 SIMCTL_CHILD_SCREENSHOT_MODE=drawcanvas
# 涂掉宿主机的摄像头挖孔
ffmpeg -hide_banner -loglevel error -y -i "$TEX/inner.png" \
  -vf "drawbox=x=1160:y=36:w=186:h=186:color=0xF9F0FF@1:t=fill" /tmp/_sn.png && mv /tmp/_sn.png "$TEX/inner.png"

echo "▶ 外屏（横版 678×466，计时钉在 42）"
for v in "cover.png:" "cover-correct.png:COVER_CELEBRATE=1" "cover-skip.png:COVER_CELEBRATE=skip"; do
  name=${v%%:*}; extra=${v#*:}
  shot "$name" "-" SIMCTL_CHILD_PREVIEW_COVER=1 SIMCTL_CHILD_COVER_MODE=drawing \
    SIMCTL_CHILD_COVER_BORDER=0 SIMCTL_CHILD_COVER_SIZE=678x466 \
    SIMCTL_CHILD_COVER_REMAINING=42 SIMCTL_CHILD_SKIP_CAMERA=1 ${extra:+SIMCTL_CHILD_$extra}
  sips -r -90 "$TEX/$name" >/dev/null
done
python3 media/duo-video/fill_band.py "$TEX"/cover*.png
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
echo "✓ $TEX"
