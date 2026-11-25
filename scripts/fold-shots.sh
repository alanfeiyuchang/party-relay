#!/usr/bin/env bash
# 把 App 的每一页按 iPhone Duo 的两种姿态各拍一张，用来验折叠布局。
#
#   scripts/fold-shots.sh                  # 内屏 90° 笔记本姿态（默认）
#   scripts/fold-shots.sh --flat           # 内屏摊平（不分屏），对照用
#   scripts/fold-shots.sh --outer          # 外屏 466×678（手机合上时 App 跑的地方）
#   scripts/fold-shots.sh --cover          # 外屏上那块「给对面看」的内容
#   scripts/fold-shots.sh --modes act,draw # 只拍这几页
#   scripts/fold-shots.sh --no-build       # 别重新构建（几个人同时拍图时用）
#
# 为什么要这么拍：模拟器**折不了**（`simctl` 没有改姿态的命令，只能在 DeviceHub 里点），
# 所以 90° 那套布局没法用真实姿态验。旁路是 FoldPreview：把整个 App 钉在内屏的点数上排版，
# 再整体缩进模拟器窗口。校准过——同样尺寸下和真机截图 SSIM≈0.996，差的那点是它隐掉的状态栏。
#
# 真机实测：内屏**两种朝向都会出现**，跟着机身走——机身竖着拿时 App 拿到的是横版
# （951×669，状态栏在右边那条 84pt 竖带），机身横过来才是竖版（669×951，顶上 82pt）。
# 下面喂的是竖版那一种，所以 laptop 这套图只对应「机身横着拿」的情形。见 docs/iphone-duo.md。
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

BUNDLE=com.partyrelay.app
# 竖版那一种（机身横着拿时 App 拿到的）。真机实测安全区就是 0,0,34,0 + 顶上 82，
# 这里沿用 0,0,34,84 是为了保住外屏那条竖带的版面压力——横版那一种要等
# 「折叠版面要不要做横屏」定了再说。
INNER_SIZE=669x951
INNER_INSETS=0,0,34,84
OUT=Screenshots/fold-check
POSTURE=laptop
BUILD=1
MODES="menu,home,wheel,handoff,act,openbuzz,draw,drawcanvas,emoji,emojiguess,hofpeek,hofsplit,scoreboard,result,smallboard,victory,settings,exitconfirm,rotationhandoff,rotationresult,foldintro,foldintrodraw"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flat)     POSTURE=flat; shift ;;
    --outer)    POSTURE=outer; shift ;;
    --cover)    POSTURE=cover; shift ;;
    --modes)    MODES=$2; shift 2 ;;
    --out)      OUT=$2; shift 2 ;;
    --device)   UDID=$2; shift 2 ;;
    # 几个人同时拍图时用：共用一个 SYMROOT，并发 xcodebuild 会互相踩
    --no-build) BUILD=0; shift ;;
    *) echo "不认识的参数：$1" >&2; exit 2 ;;
  esac
done

# 按**机型**找 Duo，不按显示名。
#
# 两个坑都踩过：按名字抓行再取最后一个字段，取到的是 `(Booted)` 而不是 UUID，
# 于是 `simctl io Booted` 落到别的已启动模拟器上，拍出一块 3840×2160 的外接屏；
# 而按名字匹配「iPhone Duo」在设备被改过名之后（比如 "Duo TEST"）直接找不到。
# deviceTypeIdentifier 不会因为改名而变。
duo_udids() {
  xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for rt, devs in d.items():
    for v in devs:
        if "iPhone-Duo" in v.get("deviceTypeIdentifier",""):
            print(v["udid"])
'
}

UDID=${UDID:-$(duo_udids | head -1)}
[[ -n "$UDID" ]] || { echo "找不到 iPhone Duo 模拟器" >&2; exit 1; }

# --device 可以指任意机型：钉尺寸那条旁路（laptop / flat / cover）在哪台机器上都成立，
# 只是宿主屏越大缩得越少。但 --outer 的前提是「模拟器主屏**就是**外屏」，
# 这只有 Duo 停在闭合姿态时才成立，换台机器拍出来的是另一块屏，图是废的
IS_DUO=$(duo_udids | grep -c "^$UDID$" || true)
if [[ "$POSTURE" == "outer" && "$IS_DUO" != "1" ]]; then
  echo "✗ --outer 只能在 iPhone Duo 上拍：主屏得**是**外屏。当前设备不是 Duo。" >&2
  exit 1
fi
if [[ "$IS_DUO" != "1" ]]; then
  echo "  （注意：当前设备不是 Duo，走的是钉尺寸的脚手架；版面比例对，像素被缩过）"
fi

if [[ "$BUILD" == "1" ]]; then
  echo "▶ 构建（Debug，模拟器）…"
  xcodebuild -project PartyRelay.xcodeproj -target PartyRelay -sdk iphonesimulator \
    -configuration Debug -arch arm64 build CODE_SIGNING_ALLOWED=NO SYMROOT=build -quiet 2>/dev/null \
    || { echo "构建失败" >&2; exit 1; }
else
  [[ -d build/Debug-iphonesimulator/PartyRelay.app ]] \
    || { echo "--no-build 但 build/ 里没有包，先不带这个参数跑一次" >&2; exit 1; }
fi

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" build/Debug-iphonesimulator/PartyRelay.app

SCREEN=${SCREEN:-}
EXPECT_PX=""

DIR="$OUT/$POSTURE"
mkdir -p "$DIR"

# 每种姿态喂给 App 的那组环境变量
env_for() {
  case "$POSTURE" in
    laptop) echo "SIMCTL_CHILD_FOLD_SIZE=$INNER_SIZE SIMCTL_CHILD_FOLD_INSETS=$INNER_INSETS SIMCTL_CHILD_FORCE_LAPTOP=1" ;;
    flat)   echo "SIMCTL_CHILD_FOLD_SIZE=$INNER_SIZE SIMCTL_CHILD_FOLD_INSETS=$INNER_INSETS" ;;
    # 外屏不用钉尺寸：模拟器停在闭合姿态时，主屏**就是**外屏
    outer)  echo "" ;;
    cover)  echo "SIMCTL_CHILD_PREVIEW_COVER=1" ;;
  esac
}
EXTRA=$(env_for)

# 平均亮度，0＝全黑。没有 ffmpeg 就回显空串（调用方据此跳过亮度判断）
screen_luma() {
  command -v ffmpeg >/dev/null || return 0
  ffmpeg -hide_banner -loglevel error -i "$1" -vf "scale=1:1" \
    -f rawvideo -pix_fmt gray - 2>/dev/null | od -An -tu1 | tr -d ' \n'
}

# 挑屏这件事必须**在 App 已经跑起来之后**做。踩过三次：
#   1. 写死 `--display 1`——两台 Duo 上 1 号不是同一块屏，一台外屏一台内屏；
#   2. 闲时挑屏——空闲时亮着的那块，不一定是 App 启动后去的那块（有一台正好相反）；
#   3. 只判几何不判亮度——黑屏的几何也对，于是整轮 9 张字节数一模一样的全黑图，
#      脚本还一声不吭当成功了。
# 所以：几何对得上外屏（两种朝向都认）**且画面不是黑的**，才用这块屏。
resolve_screen() {
  local d probe geom luma
  probe=$(mktemp -t foldshot).png
  for d in 1 3 0 2 4; do
    xcrun simctl io "$UDID" screenshot --display "$d" "$probe" >/dev/null 2>&1 || continue
    geom=$(sips -g pixelWidth -g pixelHeight "$probe" 2>/dev/null \
           | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
    case "$geom" in 1398x2034|2034x1398) ;; *) continue ;; esac
    luma=$(screen_luma "$probe")
    [[ -z "$luma" ]] && luma=99          # 没有 ffmpeg 就不判亮度，别卡住
    (( luma <= 6 )) && continue          # 这块屏是黑的，App 不在上面
    SCREEN=$d
    EXPECT_PX=$geom
    rm -f "$probe"
    echo "  （设备 ${UDID:0:8}，外屏＝display $SCREEN，$EXPECT_PX）"
    return 0
  done
  rm -f "$probe"
  echo "✗ ${UDID:0:8} 上没有一块亮着的外屏。" >&2
  echo "  模拟器可能整台是暗的——点一下它的窗口唤醒，或用 --device 换另一台 Duo。" >&2
  exit 1
}

shoot() {   # shoot <输出名> <额外环境变量…>
  local name=$1; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 0.6
  # shellcheck disable=SC2086
  env $EXTRA "$@" SIMCTL_CHILD_SKIP_CAMERA=1 \
    xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep 2
  [[ -n "$SCREEN" ]] || resolve_screen

  # 不能固定 sleep：玩法页开局有 3-2-1，固定等法正好压在倒计时结束的切换点上，
  # 偶尔拍到一张两边都没画完的中间态——那会被当成「整页空白」的 bug 报上来。
  # 5 秒是下限（上面已经等过 2 秒），之后再等画面**稳定**：连拍两张大小接近才算定住
  sleep 5
  local prev=0 now=0 try
  for try in 1 2 3 4 5; do
    xcrun simctl io "$UDID" screenshot --display "$SCREEN" "$DIR/$name.png" >/dev/null 2>&1
    now=$(stat -f%z "$DIR/$name.png" 2>/dev/null || echo 0)
    if [[ "$prev" -gt 0 ]] && awk "BEGIN{exit !($now > $prev*0.98 && $now < $prev*1.02)}"; then
      break
    fi
    prev=$now
    sleep 1.2
  done

  local got
  got=$(sips -g pixelWidth -g pixelHeight "$DIR/$name.png" 2>/dev/null \
        | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
  if [[ "$got" != "$EXPECT_PX" ]]; then
    echo "  ✗ $name 拍到了 $got，前面几张是 $EXPECT_PX —— 中途换屏了" >&2
    exit 1
  fi
  local luma
  luma=$(screen_luma "$DIR/$name.png")
  if [[ -n "$luma" ]] && (( luma <= 2 )); then
    echo "  ✗ $name 是一张全黑图——App 多半没在这块屏上。别把黑图当结果。" >&2
    exit 1
  fi

  # 横版外屏那几张：CoverPreview 为了塞进竖着的模拟器窗口先转了 +90°，这里转回来。
  # 不转的话截出来的人是躺着的，根本没法判断版面对不对
  if [[ -n "${UNROTATE:-}" ]]; then
    sips -r "$UNROTATE" "$DIR/$name.png" >/dev/null 2>&1 || true
  fi
  printf "  %s\n" "$name"
}

if [[ "$POSTURE" == "cover" ]]; then
  echo "▶ 外屏内容 → $DIR"
  # 横版：真机摆成笔记本姿势时外屏那一面是横的（678×466）
  UNROTATE=-90
  shoot question     SIMCTL_CHILD_COVER_SIZE=678x466
  shoot question-5s  SIMCTL_CHILD_COVER_SIZE=678x466
  shoot correct      SIMCTL_CHILD_COVER_SIZE=678x466 SIMCTL_CHILD_COVER_CELEBRATE=1
  shoot correct-2    SIMCTL_CHILD_COVER_SIZE=678x466 SIMCTL_CHILD_COVER_CELEBRATE=1 SIMCTL_CHILD_COVER_SCORERS=2
  shoot skip         SIMCTL_CHILD_COVER_SIZE=678x466 SIMCTL_CHILD_COVER_CELEBRATE=skip
  shoot drawing      SIMCTL_CHILD_COVER_SIZE=678x466 SIMCTL_CHILD_COVER_MODE=drawing
  shoot drawing-wide SIMCTL_CHILD_COVER_SIZE=678x466 SIMCTL_CHILD_COVER_MODE=drawing SIMCTL_CHILD_COVER_ASPECT=1.84
  # 竖版对照：真机要是给的是竖的 466×678，版面得照样站得住
  shoot question-portrait SIMCTL_CHILD_COVER_SIZE=466x678
  shoot drawing-portrait  SIMCTL_CHILD_COVER_SIZE=466x678 SIMCTL_CHILD_COVER_MODE=drawing
else
  echo "▶ $POSTURE → $DIR"
  IFS=',' read -ra LIST <<< "$MODES"
  for m in "${LIST[@]}"; do
    shoot "$m" "SIMCTL_CHILD_SCREENSHOT_MODE=$m"
  done
fi

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
echo "✓ $DIR （$(ls "$DIR" | wc -l | tr -d ' ') 张）"
