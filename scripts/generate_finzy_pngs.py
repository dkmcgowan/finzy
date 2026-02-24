"""
Generate finzy PNG assets from assets/finzy.svg:
- finzy.png: 1024x1024 transparent
- finzy_android_foreground.png: 1440x1440, icon centered (same icon size as 1024x1024)
- finzy_monochrome.png: 1440x1440, same layout, monochrome

Logic matches scripts/generate_android_icons.sh: non-square SVG is rendered with
aspect ratio preserved, fitted inside the target size, then centered on canvas.
Run from repo root:  python scripts/generate_finzy_pngs.py
"""
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
ASSETS = os.path.join(REPO_ROOT, "assets")
SVG_PATH = os.path.join(ASSETS, "finzy.svg")

ICON_SIZE = 1024
FOREGROUND_SIZE = 1440


def get_svg_viewbox(svg_path: str) -> tuple[float, float] | None:
    """Parse viewBox from SVG; return (width, height) or None."""
    with open(svg_path, encoding="utf-8") as f:
        text = f.read()
    parts = re.search(r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)\s*"', text)
    if not parts:
        return None
    return float(parts.group(1)), float(parts.group(2))


"""
Generate finzy PNG assets from assets/finzy.svg:
- finzy.png: 1024x1024 transparent
- finzy_android_foreground.png: 1440x1440, icon centered (same icon size as 1024x1024)
- finzy_monochrome.png: 1440x1440, same layout, monochrome

Logic matches scripts/generate_android_icons.sh: non-square SVG is rendered with
aspect ratio preserved, fitted inside the target size, then centered on canvas.

Requires either:
  - cairosvg + Cairo (pip install cairosvg; on Windows you may need GTK3 runtime for Cairo), or
  - ImageMagick (magick) on PATH: https://imagemagick.org/script/download.php#windows
Run from repo root:  python scripts/generate_finzy_pngs.py
"""
import os
import re
import subprocess
import sys
import tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
ASSETS = os.path.join(REPO_ROOT, "assets")
SVG_PATH = os.path.join(ASSETS, "finzy.svg")

ICON_SIZE = 1024
FOREGROUND_SIZE = 1440
# Icon size inside the 1440x1440 foreground/monochrome canvas (scale to fit inside this box)
FOREGROUND_ICON_MAX_WIDTH = 630
FOREGROUND_ICON_MAX_HEIGHT = 705


def get_svg_viewbox(svg_path: str) -> tuple[float, float] | None:
    """Parse viewBox from SVG; return (width, height) or None."""
    with open(svg_path, encoding="utf-8") as f:
        text = f.read()
    parts = re.search(r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)\s*"', text)
    if not parts:
        return None
    return float(parts.group(1)), float(parts.group(2))


def render_svg_via_imagemagick(svg_path: str, size: int, out_path: str) -> bool:
    try:
        subprocess.run(
            [
                "magick",
                "-background", "none",
                svg_path,
                "-resize", f"{size}x{size}",
                "-gravity", "center",
                "-extent", f"{size}x{size}",
                out_path,
            ],
            check=True,
            capture_output=True,
        )
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def render_svg_to_icon_1024_cairo(icon_1024_ref: list) -> bool:
    """Use cairosvg to render SVG; set icon_1024_ref[0] to PIL Image. Return True on success."""
    try:
        import cairosvg
    except (ImportError, OSError):
        # OSError: "no library called cairo-2" on Windows when Cairo DLL missing
        return False
    try:
        from PIL import Image
        import io
    except ImportError:
        return False

    viewbox = get_svg_viewbox(SVG_PATH)
    try:
        if viewbox:
            vb_w, vb_h = viewbox
            scale = min(ICON_SIZE / vb_w, ICON_SIZE / vb_h)
            out_w = int(round(vb_w * scale))
            out_h = int(round(vb_h * scale))
            buf = io.BytesIO()
            cairosvg.svg2png(
                url=SVG_PATH,
                write_to=buf,
                output_width=out_w,
                output_height=out_h,
                background_color=None,
            )
            buf.seek(0)
            icon_fit = Image.open(buf).convert("RGBA")
            icon_1024 = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
            x = (ICON_SIZE - icon_fit.width) // 2
            y = (ICON_SIZE - icon_fit.height) // 2
            icon_1024.paste(icon_fit, (x, y), icon_fit)
        else:
            buf = io.BytesIO()
            cairosvg.svg2png(
                url=SVG_PATH,
                write_to=buf,
                output_width=ICON_SIZE,
                output_height=ICON_SIZE,
                background_color=None,
            )
            buf.seek(0)
            icon_1024 = Image.open(buf).convert("RGBA")
        icon_1024_ref[0] = icon_1024
        return True
    except (OSError, Exception):
        return False


def main():
    try:
        from PIL import Image
    except ImportError:
        print("Install Pillow: pip install Pillow", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(SVG_PATH):
        print(f"SVG not found: {SVG_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Writing PNGs to: {os.path.abspath(ASSETS)}", flush=True)
    os.makedirs(ASSETS, exist_ok=True)

    icon_1024 = None

    # 1) Try cairosvg (can fail on Windows with "no library called cairo-2")
    ref = [None]
    if render_svg_to_icon_1024_cairo(ref):
        icon_1024 = ref[0]
        print("Using cairosvg for SVG rasterization.", flush=True)
    if icon_1024 is None:
        # 2) Fallback: ImageMagick
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            tmp = f.name
        try:
            if render_svg_via_imagemagick(SVG_PATH, ICON_SIZE, tmp):
                icon_1024 = Image.open(tmp).convert("RGBA")
                print("Using ImageMagick (magick) for SVG rasterization.", flush=True)
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
    if icon_1024 is None:
        print(
            "Could not render SVG. On Windows, cairosvg often needs the Cairo DLL.\n"
            "  Option A: Install ImageMagick and add it to PATH:\n"
            "    https://imagemagick.org/script/download.php#windows\n"
            "  Option B: Install GTK3 runtime (includes Cairo) then: pip install cairosvg",
            file=sys.stderr,
        )
        sys.exit(1)

    finzy_png = os.path.join(ASSETS, "finzy.png")
    icon_1024.save(finzy_png, "PNG")
    print(f"Wrote {finzy_png} ({ICON_SIZE}x{ICON_SIZE})")

    # 2) 1440x1440 with icon scaled to fit in 630x705 box, centered
    scale = min(
        FOREGROUND_ICON_MAX_WIDTH / icon_1024.width,
        FOREGROUND_ICON_MAX_HEIGHT / icon_1024.height,
    )
    icon_w = int(round(icon_1024.width * scale))
    icon_h = int(round(icon_1024.height * scale))
    icon_small = icon_1024.resize((icon_w, icon_h), Image.LANCZOS)
    w, h = FOREGROUND_SIZE, FOREGROUND_SIZE
    pad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - icon_small.width) // 2
    y = (h - icon_small.height) // 2
    pad.paste(icon_small, (x, y), icon_small)
    foreground_path = os.path.join(ASSETS, "finzy_android_foreground.png")
    pad.save(foreground_path, "PNG")
    print(f"Wrote {foreground_path} ({w}x{h}, icon {icon_small.width}x{icon_small.height} centered)")

    # 3) Monochrome: same as foreground, grayscale (preserve alpha)
    r, g, b, a = pad.split()
    rgb_only = Image.merge("RGB", (r, g, b))
    gray = rgb_only.convert("L")
    mono_rgba = Image.new("RGBA", pad.size)
    mono_rgba.paste(Image.merge("RGB", (gray, gray, gray)), (0, 0), a)
    mono_path = os.path.join(ASSETS, "finzy_monochrome.png")
    mono_rgba.save(mono_path, "PNG")
    print(f"Wrote {mono_path} ({w}x{h}, monochrome)")


if __name__ == "__main__":
    main()
