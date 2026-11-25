#!/bin/bash
# 出商店截图用的那两张 3D 图（App Store Connect 的 iPhone Duo 位）。
#
# 为什么要单独一个脚本：这组相机参数不是随手调出来的，是跟画幅绑死的。
# ASC 的 Duo 位收 2853×2007 横版，而 SHOTS 里那两组镜头当初是按 9:16 竖版定的。
# Blender 默认 sensor_fit=AUTO，把 36mm 传感器贴在**长边**上——竖版贴高度，横版贴宽度，
# 于是同样的焦距换到横版，垂直视野直接少三成，手机下半截被切到画外。
#   --fit vertical   把传感器钉在高度上，取景不再跟着长边跑
#   --lens-scale     在此基础上把主体再缩一点，给顶上的标题腾地方（0.62 实拍试出来的）
#   --aim-dz         抬高视点，把手机压到画面下半部，标题那块留空
#
# 换画幅（比如以后 ASC 改尺寸）必须重新试这三个数，别照搬。
set -euo pipefail
cd "$(dirname "$0")"
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
RES=${RES:-2853x2007}
mkdir -p store

for cfg in "store-fold:tex:duo-store-fold" \
           "store-cover:tex:duo-store-cover" \
           "store-fold:tex-en:en-duo-store-fold" \
           "store-cover:tex-en:en-duo-store-cover"; do
  shot=${cfg%%:*}; rest=${cfg#*:}; tex=${rest%%:*}; out=${rest##*:}
  "$BLENDER" -b -P scene.py -- \
    --shot "$shot" --tex "$tex" --res "$RES" \
    --fit vertical --lens-scale 0.62 --aim-dz 0.03 \
    --samples "${SAMPLES:-64}" --out "store/$out.png" >/dev/null
  echo "  store/$out.png"
done

echo "接着跑：python3 AppStoreConnect/scripts/fold_promo.py --duo"
