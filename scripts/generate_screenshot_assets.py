#!/usr/bin/env python3
"""
Generate all screenshot-derived assets from the 16 base screenshots.

Source screenshots (in assets/screenshots/):
  4 devices × 4 screens: desktop, tablet, phone, tv × home, library, media-card, season
  e.g. desktop-home.png, tablet-library.png, phone-media-card.png, tv-season.png

Outputs:
  - webp/              — WebP versions of all 16 screenshots (same filenames)
  - extras/             — playstore-feature-graphic.png (1024×500, tablet-home resize+crop), tv-banner (letterbox)
  - amazonfire-tablet/  — 4 screenshots at 1920×1200 (letterbox), icons unchanged
  - amazonfire-tv/      — 4 screenshots at 1920×1080 (letterbox), background = copy of tv-home
  - appstore-ipad/      — 4 screenshots at 2752×2064 (letterbox)
  - appstore-iphone/    — 4 screenshots at 1284×2778 (cover)

Run from repo root: python scripts/generate_screenshot_assets.py
Requires: pip install Pillow
"""
import os
import shutil
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
SCREENSHOTS = os.path.join(REPO_ROOT, "assets", "screenshots")
ASSETS = os.path.join(REPO_ROOT, "assets")
ANDROID_RES = os.path.join(REPO_ROOT, "android", "app", "src", "main", "res")

DEVICES = ("desktop", "tablet", "phone", "tv")
SCREENS = ("home", "library", "media-card", "season")

WEBP_QUALITY = 85


def get_source_path(device: str, screen: str) -> str:
    return os.path.join(SCREENSHOTS, f"{device}-{screen}.png")


def resize_contain(img, target_size, bg_color=(0, 0, 0)):
    """Scale image to fit inside target, letterbox/pillarbox as needed."""
    from PIL import Image

    out = Image.new("RGB", target_size, bg_color)
    img = img.convert("RGB")
    img.thumbnail(target_size, Image.LANCZOS)
    x = (target_size[0] - img.width) // 2
    y = (target_size[1] - img.height) // 2
    out.paste(img, (x, y))
    return out


def resize_cover(img, target_size):
    """Scale image to fill target, center crop if needed."""
    from PIL import Image

    img = img.convert("RGB")
    tw, th = target_size
    sw, sh = img.size
    ratio = max(tw / sw, th / sh)
    nw = int(sw * ratio)
    nh = int(sh * ratio)
    img = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))


def main():
    try:
        from PIL import Image
    except ImportError:
        print("Install Pillow: pip install Pillow", file=sys.stderr)
        sys.exit(1)

    # --- WebP ---
    webp_dir = os.path.join(SCREENSHOTS, "webp")
    os.makedirs(webp_dir, exist_ok=True)
    print("WebP (assets/screenshots/webp/)")
    for device in DEVICES:
        for screen in SCREENS:
            src = get_source_path(device, screen)
            if not os.path.isfile(src):
                print(f"  Skip {device}-{screen}: not found")
                continue
            out_path = os.path.join(webp_dir, f"{device}-{screen}.webp")
            try:
                img = Image.open(src)
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGBA")
                else:
                    img = img.convert("RGB")
                img.save(out_path, "WEBP", quality=WEBP_QUALITY)
                print(f"  {device}-{screen}.webp")
                img.close()
            except Exception as e:
                print(f"  Error {device}-{screen}: {e}", file=sys.stderr)

    # --- Extras ---
    extras_dir = os.path.join(SCREENSHOTS, "extras")
    os.makedirs(extras_dir, exist_ok=True)
    print("\nExtras (assets/screenshots/extras/)")
    # playstore-feature-graphic: 1024×500, tablet-home resize to 1024×640 then center crop
    tablet_home = get_source_path("tablet", "home")
    if os.path.isfile(tablet_home):
        img = Image.open(tablet_home).convert("RGB")
        img = img.resize((1024, 640), Image.LANCZOS)
        # Crop top 500px, discard bottom
        img = img.crop((0, 0, 1024, 500))
        out_path = os.path.join(extras_dir, "playstore-feature-graphic.png")
        img.save(out_path, "PNG")
        print(f"  playstore-feature-graphic.png (1024×500, tablet-home)")
        img.close()
    else:
        print(f"  Skip playstore-feature-graphic: {tablet_home} not found")
    # tv-banner: 1280×720, letterbox from tv-home
    tv_home = os.path.join(SCREENSHOTS, "tv-home.png")
    if os.path.isfile(tv_home):
        img = Image.open(tv_home)
        out = resize_contain(img, (1280, 720))
        out_path = os.path.join(extras_dir, "tv-banner-1280x720.png")
        out.save(out_path, "PNG")
        print(f"  tv-banner-1280x720.png (1280×720)")
        img.close()
    else:
        print(f"  Skip tv-banner: {tv_home} not found")

    # --- Amazon Fire Tablet ---
    tablet_dir = os.path.join(SCREENSHOTS, "amazonfire-tablet")
    os.makedirs(tablet_dir, exist_ok=True)
    print("\nAmazon Fire Tablet (1920×1200, letterbox)")
    for screen in SCREENS:
        src = get_source_path("tablet", screen)
        if not os.path.isfile(src):
            print(f"  Skip tablet-{screen}: not found")
            continue
        img = Image.open(src)
        out = resize_contain(img, (1920, 1200))
        out_path = os.path.join(tablet_dir, f"tablet-{screen}-1920x1200.png")
        out.save(out_path, "PNG")
        print(f"  tablet-{screen}-1920x1200.png")
        img.close()

    # Tablet icons (unchanged - from finzy.png)
    icon_src = os.path.join(ASSETS, "finzy.png")
    if not os.path.isfile(icon_src):
        icon_src = os.path.join(ASSETS, "finzy_android_foreground.png")
    if os.path.isfile(icon_src):
        icon = Image.open(icon_src).convert("RGBA")
        for size in (512, 114):
            out = icon.resize((size, size), Image.LANCZOS)
            out_path = os.path.join(tablet_dir, f"icon-{size}x{size}.png")
            out.save(out_path, "PNG")
            print(f"  icon-{size}x{size}.png")
        icon.close()

    # --- Amazon Fire TV ---
    tv_dir = os.path.join(SCREENSHOTS, "amazonfire-tv")
    os.makedirs(tv_dir, exist_ok=True)
    print("\nAmazon Fire TV (1920×1080, letterbox)")
    for screen in SCREENS:
        src = get_source_path("tv", screen)
        if not os.path.isfile(src):
            print(f"  Skip tv-{screen}: not found")
            continue
        img = Image.open(src)
        out = resize_contain(img, (1920, 1080))
        out_path = os.path.join(tv_dir, f"tv-{screen}-1920x1080.png")
        out.save(out_path, "PNG")
        print(f"  tv-{screen}-1920x1080.png")
        img.close()

    # background = copy of tv-home-1920x1080
    tv_home_1080 = os.path.join(tv_dir, "tv-home-1920x1080.png")
    if os.path.isfile(tv_home_1080):
        bg_path = os.path.join(tv_dir, "background-1920x1080.png")
        shutil.copy2(tv_home_1080, bg_path)
        print(f"  background-1920x1080.png (copy of tv-home)")
    # tv_banner-1280x720: leave alone (icon, not regenerated)

    # --- App Store iPad ---
    ipad_dir = os.path.join(SCREENSHOTS, "appstore-ipad")
    os.makedirs(ipad_dir, exist_ok=True)
    print("\nApp Store iPad (2752×2064, letterbox)")
    for screen in SCREENS:
        src = get_source_path("tablet", screen)
        if not os.path.isfile(src):
            print(f"  Skip tablet-{screen}: not found")
            continue
        img = Image.open(src)
        out = resize_contain(img, (2752, 2064))
        out_path = os.path.join(ipad_dir, f"tablet-{screen}.png")
        out.save(out_path, "PNG")
        print(f"  tablet-{screen}.png")
        img.close()

    # --- App Store iPhone ---
    iphone_dir = os.path.join(SCREENSHOTS, "appstore-iphone")
    os.makedirs(iphone_dir, exist_ok=True)
    print("\nApp Store iPhone (1284×2778, cover)")
    for screen in SCREENS:
        src = get_source_path("phone", screen)
        if not os.path.isfile(src):
            print(f"  Skip phone-{screen}: not found")
            continue
        img = Image.open(src)
        out = resize_cover(img, (1284, 2778))
        out_path = os.path.join(iphone_dir, f"phone-{screen}.png")
        out.save(out_path, "PNG")
        print(f"  phone-{screen}.png")
        img.close()

    print("\nDone. Run this script again after updating base screenshots.")


if __name__ == "__main__":
    main()
