"""Resize the canonical 1290x2796 (6.7") promo set into other required
App Store Connect display-size buckets. The aspect ratios differ by under
0.3% across these targets, so a direct high-quality resize is visually
lossless -- no need to re-render each size from HTML.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # AppStoreConnect/
SRC = os.path.join(ROOT, "PromoImages")

# (folder suffix, target size) -- App Store Connect iPhone screenshot buckets
SIZES = {
    "6.9in-1320x2868": (1320, 2868),
    "6.5in-1284x2778": (1284, 2778),
}

SOURCE_DIRS = ["hero", "feature", "tilt", "hero-photo"]

def main():
    count = 0
    for suffix, (w, h) in SIZES.items():
        for src_dir in SOURCE_DIRS:
            src_root = os.path.join(SRC, src_dir)
            if not os.path.isdir(src_root):
                continue
            for dirpath, _, filenames in os.walk(src_root):
                for fname in filenames:
                    if not fname.lower().endswith(".png"):
                        continue
                    src_path = os.path.join(dirpath, fname)
                    rel = os.path.relpath(src_path, SRC)
                    dst_path = os.path.join(SRC, suffix, rel)
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    img = Image.open(src_path).convert("RGB")
                    resized = img.resize((w, h), Image.LANCZOS)
                    resized.save(dst_path)
                    count += 1
    print(f"Wrote {count} resized images across {len(SIZES)} size buckets.")

if __name__ == "__main__":
    main()
