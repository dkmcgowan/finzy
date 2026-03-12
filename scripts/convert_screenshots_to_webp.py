"""
Convert PNG screenshots to WebP format.

DEPRECATED: Use scripts/generate_screenshot_assets.py instead, which outputs
to assets/screenshots/webp/ and handles all screenshot-derived assets.

This script kept for backwards compatibility; it outputs .webp alongside .png.
Requires: pip install Pillow

Run from repo root: python scripts/convert_screenshots_to_webp.py
"""
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Requires Pillow. Install with: pip install Pillow")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SCREENSHOTS_DIR = REPO_ROOT / "assets" / "screenshots"

QUALITY = 85


def main() -> None:
    if not SCREENSHOTS_DIR.exists():
        print(f"Directory not found: {SCREENSHOTS_DIR}")
        sys.exit(1)

    pngs = sorted(SCREENSHOTS_DIR.glob("*.png"))
    if not pngs:
        print(f"No PNG files in {SCREENSHOTS_DIR}")
        sys.exit(0)

    for png_path in pngs:
        webp_path = png_path.with_suffix(".webp")
        try:
            img = Image.open(png_path)
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGBA")
            else:
                img = img.convert("RGB")
            img.save(webp_path, "WEBP", quality=QUALITY)
            print(f"  {png_path.name} -> {webp_path.name}")
        except Exception as e:
            print(f"  Error converting {png_path.name}: {e}", file=sys.stderr)

    print(f"\nConverted {len(pngs)} screenshots to WebP in {SCREENSHOTS_DIR}")


if __name__ == "__main__":
    main()
