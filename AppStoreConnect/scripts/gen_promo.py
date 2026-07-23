import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from people import person_svg, confetti_svg

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCREENS = os.path.join(ROOT, "AppStoreConnect", "_build", "fresh_screens")
HTML_OUT = os.path.join(ROOT, "AppStoreConnect", "_build", "html")
os.makedirs(HTML_OUT, exist_ok=True)

W, H = 1290, 2796

FONT = '-apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif'

BASE_CSS = f'''
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; font-family:{FONT}; }}
.canvas {{ position:relative; width:{W}px; height:{H}px; }}
.bg {{ position:absolute; inset:0; }}
.deco {{ position:absolute; inset:0; }}
.phone {{
    position:absolute;
    background:#111;
    border-radius:64px;
    box-shadow: 0 40px 90px rgba(0,0,0,0.35), 0 10px 30px rgba(0,0,0,0.25);
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
    position:absolute; left:60px; right:60px; text-align:center;
    font-weight:800; color:#fff; text-shadow: 0 4px 18px rgba(0,0,0,0.28);
    line-height:1.18;
}}
.subline {{
    position:absolute; left:90px; right:90px; text-align:center;
    color:rgba(255,255,255,0.92); font-weight:600; text-shadow: 0 2px 10px rgba(0,0,0,0.25);
}}
.wordmark {{
    position:absolute; left:0; right:0; text-align:center;
    font-weight:800; letter-spacing:0.5px;
}}
.pill {{
    position:absolute; padding:20px 40px; border-radius:999px;
    font-weight:700; color:#fff; text-shadow:0 2px 8px rgba(0,0,0,0.2);
}}
'''

def phone_html(screenshot, x, y, w, top="0%", height_ratio=2622/1206):
    h = w * height_ratio
    pad = w * 0.028
    notch_top = pad + 2
    return f'''
    <div class="phone" style="left:{x}px; top:{y}px; width:{w:.0f}px; height:{h:.0f}px;">
        <div class="screen" style="left:{pad:.0f}px; top:{pad:.0f}px; width:{w-2*pad:.0f}px; height:{h-2*pad:.0f}px;">
            <img src="file://{SCREENS}/{screenshot}">
        </div>
        <div class="notch"></div>
    </div>
    '''

def page(body, bg):
    return f'''<!DOCTYPE html><html><head><meta charset="utf-8"><style>{BASE_CSS}</style></head>
    <body><div class="canvas">
        <div class="bg" style="background:{bg};"></div>
        {body}
    </div></body></html>'''


# ---------- Copy: hero (social/marketing) slides ----------
HERO_COPY = {
    "en": {
        "h1": ("Two Teams. One Phone.", "All the Laughs.", "Charades, drawing, lip reading & more — no setup, no ads, no internet."),
        "h2": ("Spin the Wheel.", "Race the Clock.", "One wheel, four wild party games for two teams."),
        "h3": ("Act It Out —", "No Talking!", "Charades night, built right into your pocket."),
        "h4": ("Draw It. Guess It.", "Win It.", "Sketch the word, no letters or numbers allowed."),
    },
    "zh-Hans": {
        "h1": ("两队对战，一部手机，", "笑到停不下来", "你说我猜、你画我猜、唇语猜词……零准备，无广告，不联网。"),
        "h2": ("转动转盘，", "开始限时对决", "一个转盘，四种玩法，两队轮流挑战。"),
        "h3": ("只用动作，", "不许出声！", "肢体模仿之夜，装进你的口袋。"),
        "h4": ("画出来，猜出来，", "赢下这一局", "只能画画，不能写字或数字。"),
    },
}

def hero_slide(lang, key, bg, phone_shot, people, dpi_dir):
    line1, line2, sub = HERO_COPY[lang][key]
    body = f'''
    <svg class="deco" viewBox="0 0 {W} {H}">{confetti_svg(seed=hash(key) % 97)}</svg>
    <div class="headline" style="top:150px; font-size:92px;">{line1}<br>{line2}</div>
    <div class="subline" style="top:430px; font-size:40px;">{sub}</div>
    '''
    body += phone_html(phone_shot, x=(W-720)/2, y=560, w=720)
    for (svg_x, svg_y, scale, pose, skin, shirt, hair, mirror, hair_style) in people:
        body += f'<svg style="position:absolute; left:{svg_x}px; top:{svg_y}px; width:{240*scale:.0f}px; height:{320*scale:.0f}px;" viewBox="0 0 240 320">{person_svg(pose, skin, shirt, hair, mirror, hair_style)}</svg>'
    body += f'<div class="wordmark" style="bottom:70px; font-size:44px; color:rgba(255,255,255,0.95);">🎉 PartyRelay</div>'
    return page(body, bg)


# ---------- Copy: feature/intro slides ----------
FEATURE_COPY = {
    "en": {
        "games":    ("Four Games,", "One Wheel", "Say & Guess · Draw & Guess · Lip Reading · Charades"),
        "openbuzz": ("Open Buzz:", "Steal the Point", "Land on it and the other team can jump in and score too."),
        "catchup":  ("Never a", "Blowout", "Trailing teams get a comeback boost — and late-game, they pick the next game outright."),
        "privacy":  ("Built-In", "Privacy Guard", "Hold it up to see the word, lay it flat to hide it automatically."),
        "recap":    ("Every Word,", "Remembered", "A full recap after each round settles every 'wait, was that the word?' debate."),
    },
    "zh-Hans": {
        "games":    ("一个转盘，", "四种玩法", "你说我猜 · 你画我猜 · 唇语猜词 · 肢体模仿"),
        "openbuzz": ("开放抢答：", "偷分一触即发", "转到这个扇区，对方随时可以抢答得分。"),
        "catchup":  ("比赛永远", "势均力敌", "落后队伍会获得追分加成，决胜阶段甚至能直接指定玩法。"),
        "privacy":  ("内置", "防偷窥模式", "立起手机才看到词语，放平自动隐藏。"),
        "recap":    ("每个词，", "都不会忘记", "每轮结束后的完整回顾，终结所有“这真的是这个词吗”的争论。"),
    },
}

def feature_slide(lang, key, bg, phone_shot, banner_color):
    line1, line2, sub = FEATURE_COPY[lang][key]
    body = f'''
    <div class="headline" style="top:130px; font-size:88px;">{line1}<br>{line2}</div>
    <div class="subline" style="top:410px; font-size:38px;">{sub}</div>
    '''
    body += phone_html(phone_shot, x=(W-840)/2, y=620, w=840)
    body += f'<div class="wordmark" style="bottom:70px; font-size:44px; color:rgba(255,255,255,0.95);">🎉 PartyRelay</div>'
    return page(body, bg)
