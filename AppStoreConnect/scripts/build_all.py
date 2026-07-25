import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_promo import hero_slide, feature_slide, HTML_OUT

LANGS = ["en", "zh-Hans"]
SHOT_LANG = {"en": "en", "zh-Hans": "zh"}  # screenshot filename prefix

BG = {
    "sunrise": "linear-gradient(160deg, #ff7e5f 0%, #feb47b 45%, #ff6a95 100%)",
    "ocean":   "linear-gradient(160deg, #4a86e8 0%, #43d692 55%, #6dd5ed 100%)",
    "citrus":  "linear-gradient(160deg, #56ab2f 0%, #a8e063 60%, #f7d794 100%)",
    "candy":   "linear-gradient(160deg, #a479e2 0%, #f691b3 55%, #feca57 100%)",
    "games":   "linear-gradient(160deg, #ff6b6b 0%, #feca57 100%)",
    "buzz":    "linear-gradient(160deg, #feca57 0%, #ff9f43 100%)",
    "catchup": "linear-gradient(160deg, #ff9a44 0%, #fc6076 100%)",
    "privacy": "linear-gradient(160deg, #667eea 0%, #764ba2 100%)",
    "recap":   "linear-gradient(160deg, #43cea2 0%, #185a9d 100%)",
}

# (x, y, scale, pose, skin, shirt, hair, mirror, hair_style)
HERO_PEOPLE = {
    "h1": [
        (-70, 1620, 1.7, "cheer", "#e8b08a", "#ff6b6b", "#3a2a20", False, "short"),
        (960, 1620, 1.7, "cheer", "#8d5524", "#4a86e8", "#1c1c1c", True, "wavy"),
        (330, 2280, 1.15, "laugh", "#ffdbac", "#a479e2", "#5c3a21", False, "bun"),
    ],
    "h2": [
        (-60, 1680, 1.6, "wave", "#c68642", "#43d692", "#241c14", False, "short"),
        (970, 1660, 1.65, "phone", "#ffdbac", "#feca57", "#3a2a20", True, "wavy"),
    ],
    "h3": [
        (-30, 1560, 1.85, "act", "#8d5524", "#56ab2f", "#1c1c1c", False, "short"),
        (955, 1700, 1.5, "laugh", "#e8b08a", "#f691b3", "#5c3a21", True, "bun"),
    ],
    "h4": [
        (-60, 1630, 1.65, "draw", "#ffdbac", "#a479e2", "#3a2a20", False, "wavy"),
        (965, 1650, 1.6, "laugh", "#c68642", "#feca57", "#1c1c1c", True, "short"),
    ],
}

HERO_SHOTS = {"h1": "home.png", "h2": "wheel.png", "h3": "openbuzz.png", "h4": "drawcanvas.png"}
HERO_BG = {"h1": "sunrise", "h2": "ocean", "h3": "citrus", "h4": "candy"}

FEATURE_SHOTS = {
    "games": "wheel.png",
    "openbuzz": "openbuzz.png",
    "catchup": "pick.png",
    "privacy": "privacy.png",
    "recap": "scoreboard.png",
    "drawguess": "drawcanvas.png",
    "actguess": "act.png",
}
FEATURE_BG = {"games": "games", "openbuzz": "buzz", "catchup": "catchup", "privacy": "privacy", "recap": "recap",
              "drawguess": "ocean", "actguess": "citrus"}

manifest = []

for lang in LANGS:
    shot_prefix = SHOT_LANG[lang]
    for i, key in enumerate(["h1", "h2", "h3", "h4"], start=1):
        html = hero_slide(lang, key, BG[HERO_BG[key]], f"{shot_prefix}-{HERO_SHOTS[key]}", HERO_PEOPLE[key], lang)
        fname = f"hero-{i}-{key}-{lang}.html"
        with open(os.path.join(HTML_OUT, fname), "w", encoding="utf-8") as f:
            f.write(html)
        manifest.append((fname, f"hero/{lang}/{i:02d}-hero-{key}.png"))

    for i, key in enumerate(["games", "openbuzz", "catchup", "privacy", "recap", "drawguess", "actguess"], start=1):
        html = feature_slide(lang, key, BG[FEATURE_BG[key]], f"{shot_prefix}-{FEATURE_SHOTS[key]}", FEATURE_BG[key])
        fname = f"feature-{i}-{key}-{lang}.html"
        with open(os.path.join(HTML_OUT, fname), "w", encoding="utf-8") as f:
            f.write(html)
        manifest.append((fname, f"feature/{lang}/{i:02d}-feature-{key}.png"))

with open(os.path.join(HTML_OUT, "manifest.txt"), "w") as f:
    for a, b in manifest:
        f.write(f"{a}\t{b}\n")

print(f"Wrote {len(manifest)} html files + manifest.")
