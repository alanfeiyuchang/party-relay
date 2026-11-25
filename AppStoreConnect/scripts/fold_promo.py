#!/usr/bin/env python3
"""把 Blender 渲的折叠效果图合成成 App Store 截图（1290×2796）。

和 gen_promo.py 的区别：那边是把真机截图嵌进手机壳 + 彩色渐变底 + 白字；
这边底图是 3D 渲染（浅灰的桌面和墙），白字读不出来，所以用深色字，
顶上压一层很淡的品牌紫把字托住。

    python3 AppStoreConnect/scripts/fold_promo.py
出图在 AppStoreConnect/PromoImages/fold/<lang>/
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RENDER = os.path.join(ROOT, "media", "duo-video", "store")
OUT = os.path.join(ROOT, "AppStoreConnect", "PromoImages", "fold")
TMP = os.path.join(ROOT, "AppStoreConnect", "_build", "fold_html")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1290, 2796
FONT = '-apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif'

# 每张：底图、大标题（两行）、副标题
SLIDES = {
    "zh-Hans": [
        ("store-fold.png",  "一台手机",        "两边展示",
         "实时信息，更容易看到"),
        ("store-cover.png", "外屏朝着对面",     "画到哪同步到哪",
         "不用再挤到一块儿看"),
    ],
    # 英文那两张底图是用英文界面的贴图单独渲的（scene.py --tex tex-en）
    "en": [
        ("en-store-fold.png",  "One phone",        "Both sides at once",
         "Live info, easier to see"),
        ("en-store-cover.png", "The outer screen", "Synced as you draw",
         "No crowding around one phone"),
    ],
}

PAGE = """<!doctype html><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; font-family:{FONT}; }}
.canvas {{ position:relative; width:{W}px; height:{H}px; background:#EFECF4; }}
.shot {{ position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }}
/* 底图顶上是浅灰的墙，直接放深色字有点飘——压一层很淡的品牌紫把字托住 */
.wash {{ position:absolute; left:0; right:0; top:0; height:1050px;
         background:linear-gradient(180deg, rgba(243,238,255,0.97) 0%,
                                           rgba(243,238,255,0.86) 55%,
                                           rgba(243,238,255,0) 100%); }}
.headline {{ position:absolute; left:70px; right:70px; top:150px; text-align:center;
             font-size:96px; font-weight:800; line-height:1.16; color:#241B3D;
             letter-spacing:-1px; }}
.accent {{ color:#7C4DFF; }}
.subline {{ position:absolute; left:110px; right:110px; top:{sub_top}px; text-align:center;
            font-size:40px; font-weight:600; line-height:1.45; color:#4A4066; }}
.wordmark {{ position:absolute; left:0; right:0; bottom:66px; text-align:center;
             font-size:42px; font-weight:800; color:rgba(36,27,61,0.72); }}
</style>
<div class="canvas">
  <img class="shot" src="file://{shot}">
  <div class="wash"></div>
  <div class="headline">{line1}<br><span class="accent">{line2}</span></div>
  <div class="subline">{sub}</div>
  <div class="wordmark">{mark}</div>
</div>"""

MARK = {"en": "🎉 PartyRelay", "zh-Hans": "🎉 猜词派对"}


def build(lang):
    os.makedirs(os.path.join(OUT, lang), exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    made = []
    for i, (shot, line1, line2, sub) in enumerate(SLIDES[lang], 1):
        src = os.path.join(RENDER, shot)
        if not os.path.exists(src):
            print(f"  ✗ 缺底图 {src}（先用 scene.py 渲出来）"); continue
        html = PAGE.format(W=W, H=H, FONT=FONT, shot=src, line1=line1, line2=line2,
                           sub=sub, mark=MARK[lang],
                           sub_top=150 + 96 * 2 * 1.16 + 46)
        hp = os.path.join(TMP, f"{lang}-{i}.html")
        open(hp, "w").write(html)
        dest = os.path.join(OUT, lang,
                            f"{i:02d}-fold-{shot.removeprefix('en-')}")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        f"--window-size={W},{H}", f"--screenshot={dest}", f"file://{hp}"],
                       check=True, capture_output=True)
        made.append(dest)
        print(f"  ✓ {os.path.relpath(dest, ROOT)}")
    return made


if __name__ == "__main__":
    langs = sys.argv[1:] or ["zh-Hans", "en"]
    for l in langs:
        print(f"▶ {l}")
        build(l)
