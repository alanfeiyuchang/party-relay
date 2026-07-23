import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_promo import SCREENS, HTML_OUT

W, H = 1290, 2796
FONT = '-apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif'

BASE_CSS = f'''
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; font-family:{FONT}; background:#08080d; }}
.canvas {{ position:relative; width:{W}px; height:{H}px; background:#08080d; }}
.glow {{ position:absolute; inset:0; filter: blur(90px); opacity:0.75; }}
.stage {{ position:absolute; inset:0; perspective:1800px; }}
.phone {{
    position:absolute;
    background: linear-gradient(160deg, #3a3a42, #111114);
    border-radius:64px;
    box-shadow: 0 60px 120px rgba(0,0,0,0.55), 0 0 90px rgba(255,255,255,0.05);
    transform-style: preserve-3d;
}}
.phone .screen {{
    position:absolute; overflow:hidden;
    border-radius:52px;
}}
.phone .screen img {{ width:100%; height:100%; object-fit:cover; display:block; }}
.phone .notch {{
    position:absolute; top:14px; left:50%; transform:translateX(-50%);
    width:34%; height:26px; background:#111; border-radius:14px; z-index:3;
}}
.headline {{
    position:absolute; left:70px; right:70px; text-align:center;
    font-weight:800; line-height:1.15;
}}
.wordmark {{
    position:absolute; left:0; right:0; text-align:center;
    font-weight:800; letter-spacing:0.5px; color:rgba(255,255,255,0.55);
}}
.grad-text {{ background-clip:text; -webkit-background-clip:text; color:transparent; }}
'''

def glow_svg(colors, seed=0):
    import math
    c1, c2, c3 = colors
    return f'''
    <svg class="glow" viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="g{seed}a" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="{c1}"/>
          <stop offset="100%" stop-color="{c2}"/>
        </linearGradient>
        <linearGradient id="g{seed}b" x1="100%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="{c2}"/>
          <stop offset="100%" stop-color="{c3}"/>
        </linearGradient>
      </defs>
      <ellipse cx="{W*0.18:.0f}" cy="{H*0.28:.0f}" rx="420" ry="620" fill="url(#g{seed}a)" opacity="0.55" transform="rotate(-25 {W*0.18:.0f} {H*0.28:.0f})"/>
      <ellipse cx="{W*0.85:.0f}" cy="{H*0.68:.0f}" rx="380" ry="560" fill="url(#g{seed}b)" opacity="0.5" transform="rotate(20 {W*0.85:.0f} {H*0.68:.0f})"/>
    </svg>
    '''

def phone_html(screenshot, x, y, w, rotateY, rotateX, ratio=2622/1206):
    h = w * ratio
    pad = w * 0.028
    return f'''
    <div class="phone" style="left:{x:.0f}px; top:{y:.0f}px; width:{w:.0f}px; height:{h:.0f}px;
         transform: rotateY({rotateY}deg) rotateX({rotateX}deg);">
        <div class="screen" style="left:{pad:.0f}px; top:{pad:.0f}px; width:{w-2*pad:.0f}px; height:{h-2*pad:.0f}px;">
            <img src="file://{SCREENS}/{screenshot}">
        </div>
        <div class="notch"></div>
    </div>
    '''

def page(body):
    return f'''<!DOCTYPE html><html><head><meta charset="utf-8"><style>{BASE_CSS}</style></head>
    <body><div class="canvas">{body}</div></body></html>'''


COPY = {
    "en": {
        "t1": ("Two Teams.", "One Phone.", ["#ff6b6b", "#feca57"]),
        "t2": ("Spin For Your", "Game", ["#4a86e8", "#a479e2"]),
        "t3": ("Draw It.", "Guess It.", ["#43d692", "#4a86e8"]),
    },
    "zh-Hans": {
        "t1": ("两队对战，", "一部手机", ["#ff6b6b", "#feca57"]),
        "t2": ("转动转盘，", "开始对决", ["#4a86e8", "#a479e2"]),
        "t3": ("画出来，", "猜出来", ["#43d692", "#4a86e8"]),
    },
}

SLIDES = [
    dict(key="t1", shot_suffix="home.png", rotY=-16, rotX=4, glow=["#ff6b6b", "#a479e2", "#4a86e8"]),
    dict(key="t2", shot_suffix="wheel.png", rotY=14, rotX=-3, glow=["#4a86e8", "#a479e2", "#f691b3"]),
    dict(key="t3", shot_suffix="drawcanvas.png", rotY=-12, rotX=5, glow=["#43d692", "#4a86e8", "#feca57"]),
]

def build(lang, shot_prefix):
    out = []
    for i, s in enumerate(SLIDES, start=1):
        line1, line2, textgrad = COPY[lang][s["key"]]
        body = glow_svg(s["glow"], seed=i)
        body += f'''
        <div class="headline" style="top:190px; font-size:84px; color:#fff;">
            {line1}<br><span class="grad-text" style="background-image:linear-gradient(90deg,{textgrad[0]},{textgrad[1]});">{line2}</span>
        </div>
        '''
        phone_w = 780
        phone_x = (W - phone_w) / 2 + (60 if s["rotY"] < 0 else -60)
        shot_file = f'{shot_prefix}-{s["shot_suffix"]}'
        body += f'<div class="stage">{phone_html(shot_file, phone_x, 560, phone_w, s["rotY"], s["rotX"])}</div>'
        body += '<div class="wordmark" style="bottom:80px; font-size:40px;">🎉 PartyRelay</div>'
        html = page(body)
        fname = f"tilt-{i}-{s['key']}-{lang}.html"
        with open(os.path.join(HTML_OUT, fname), "w", encoding="utf-8") as f:
            f.write(html)
        out.append((fname, f"tilt/{lang}/{i:02d}-tilt-{s['key']}.png"))
    return out


if __name__ == "__main__":
    manifest = []
    manifest += build("en", "en")
    manifest += build("zh-Hans", "zh")
    with open(os.path.join(HTML_OUT, "tilt_manifest.txt"), "w") as f:
        for a, b in manifest:
            f.write(f"{a}\t{b}\n")
    print(f"Wrote {len(manifest)} tilt html files")
