#!/usr/bin/env python3
"""
Generate Amazon Fire Store assets from existing screenshots and icons.

Amazon Fire Tablet:
- Screenshots: 1920x1200 (4 images, stretch-to-fit from root tablet-*)
- Icons: 512x512, 114x114 (PNG, transparent)

Amazon Fire TV:
- TV banner: 1280x720 (from tv_banner or generated)
- Screenshots: 1920x1080 landscape
- Background: 1920x1080 landscape (no transparency)

Run from repo root: python scripts/generate_amazonfire_assets.py
Requires: pip install Pillow
"""
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
SCREENSHOTS = os.path.join(REPO_ROOT, "assets", "screenshots")
ASSETS = os.path.join(REPO_ROOT, "assets")
ANDROID_RES = os.path.join(REPO_ROOT, "android", "app", "src", "main", "res")

# Output folders
AMAZONFIRE_TABLET = os.path.join(SCREENSHOTS, "amazonfire-tablet")
AMAZONFIRE_TV = os.path.join(SCREENSHOTS, "amazonfire-tv")

# Amazon Fire Tablet: single resolution 1920x1200 (best aspect match for tablet source)
TABLET_SIZE = (1920, 1200)

# Tablet icon sizes (PNG, transparent)
TABLET_ICON_SIZES = [512, 114]

# Fire TV
TV_BANNER_SIZE = (1280, 720)
TV_SCREENSHOT_SIZE = (1920, 1080)
TV_BACKGROUND_SIZE = (1920, 1080)


def main():
    try:
        from PIL import Image
    except ImportError:
        print("Install Pillow: pip install Pillow", file=sys.stderr)
        sys.exit(1)

    os.makedirs(AMAZONFIRE_TABLET, exist_ok=True)
    os.makedirs(AMAZONFIRE_TV, exist_ok=True)

    # --- Tablet screenshots ---
    # Use root tablet-* (2800x1752); resize/stretch to 1920x1200 (best aspect match)
    tablet_sources = [
        ("tablet-home", os.path.join(SCREENSHOTS, "tablet-home.png")),
        ("tablet-library", os.path.join(SCREENSHOTS, "tablet-library.png")),
        ("tablet-media-card", os.path.join(SCREENSHOTS, "tablet-media-card.png")),
        ("tablet-season", os.path.join(SCREENSHOTS, "tablet-season.png")),
    ]
    w, h = TABLET_SIZE
    for name, path in tablet_sources:
        if not os.path.isfile(path):
            print(f"  Skip {name}: not found", flush=True)
            continue
        try:
            img = Image.open(path).convert("RGB")
        except Exception as e:
            print(f"  Skip {name}: {e}", flush=True)
            continue
        out = img.resize((w, h), Image.LANCZOS)
        out_path = os.path.join(AMAZONFIRE_TABLET, f"{name}-{w}x{h}.png")
        out.save(out_path, "PNG")
        print(f"  Wrote {out_path}")
        img.close()

    # --- Tablet icons (512x512, 114x114, transparent) ---
    # Use finzy.png (1024x1024 transparent) or finzy_android_foreground.png
    icon_src = os.path.join(ASSETS, "finzy.png")
    if not os.path.isfile(icon_src):
        icon_src = os.path.join(ASSETS, "finzy_android_foreground.png")
    if os.path.isfile(icon_src):
        icon = Image.open(icon_src).convert("RGBA")
        for size in TABLET_ICON_SIZES:
            out = icon.resize((size, size), Image.LANCZOS)
            out_path = os.path.join(AMAZONFIRE_TABLET, f"icon-{size}x{size}.png")
            out.save(out_path, "PNG")
            print(f"  Wrote {out_path}")
        icon.close()
    else:
        print(f"  Skip icons: {icon_src} not found", flush=True)

    # --- Fire TV: tv_banner 1280x720 ---
    tv_banner_src = os.path.join(ANDROID_RES, "drawable-xxxhdpi", "tv_banner.png")
    if os.path.isfile(tv_banner_src):
        banner = Image.open(tv_banner_src).convert("RGBA")
        banner = banner.resize(TV_BANNER_SIZE, Image.LANCZOS)
        out_path = os.path.join(AMAZONFIRE_TV, "tv_banner-1280x720.png")
        banner.save(out_path, "PNG")
        print(f"  Wrote {out_path}")
        banner.close()
    else:
        print(f"  Skip tv_banner: {tv_banner_src} not found", flush=True)

    # --- Fire TV: screenshots 1920x1080 landscape ---
    tv_sources = [
        ("tv-home", os.path.join(SCREENSHOTS, "tv-home.png")),
        ("tv-library", os.path.join(SCREENSHOTS, "tv-library.png")),
        ("tv-media-card", os.path.join(SCREENSHOTS, "tv-media-card.png")),
        ("tv-season", os.path.join(SCREENSHOTS, "tv-season.png")),
    ]
    for name, path in tv_sources:
        if not os.path.isfile(path):
            print(f"  Skip {name}: not found", flush=True)
            continue
        try:
            img = Image.open(path).convert("RGB")
        except Exception as e:
            print(f"  Skip {name}: {e}", flush=True)
            continue
        out = Image.new("RGB", TV_SCREENSHOT_SIZE, (0, 0, 0))
        img.thumbnail(TV_SCREENSHOT_SIZE, Image.LANCZOS)
        paste_x = (TV_SCREENSHOT_SIZE[0] - img.width) // 2
        paste_y = (TV_SCREENSHOT_SIZE[1] - img.height) // 2
        out.paste(img, (paste_x, paste_y))
        out_path = os.path.join(AMAZONFIRE_TV, f"{name}-1920x1080.png")
        out.save(out_path, "PNG")
        print(f"  Wrote {out_path}")
        img.close()

    # --- Fire TV: background 1920x1080 (no transparency) ---
    # Use tv-home as base, optionally darkened/blurred; save as opaque
    bg_src = os.path.join(SCREENSHOTS, "tv-home.png")
    if os.path.isfile(bg_src):
        bg = Image.open(bg_src).convert("RGB")
        bg = bg.resize(TV_BACKGROUND_SIZE, Image.LANCZOS)
        out_path = os.path.join(AMAZONFIRE_TV, "background-1920x1080.png")
        bg.save(out_path, "PNG")
        print(f"  Wrote {out_path}")
        bg.close()
    else:
        print(f"  Skip background: {bg_src} not found", flush=True)

    print("")
    print("Done. Assets in assets/screenshots/amazonfire-tablet/ and amazonfire-tv/")


if __name__ == "__main__":
    main()
