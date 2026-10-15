"""Generates every Veylora brand asset from one definition of the logo.

The mark is a "V" built from two layers: an amber arm and a cream arm that
cross at the vertex, where their overlap takes a third, lighter tone. Two
layers meeting is what Veylora does: a reference lined up over the live view.

Run from the repository root (needs Pillow):

    python tool/brand/generate_brand_assets.py

Writes:
  assets/branding/      master SVGs, in-app mark PNGs (1x/2x/3x), README logo
  android/app/src/main/res/
                        legacy + adaptive launcher icons, monochrome (themed)
                        layer, launch-screen mark
  ios/Runner/Assets.xcassets/
                        AppIcon set (opaque, as App Store requires), LaunchImage
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# --- Logo definition (1024-unit canvas) -------------------------------------

CANVAS = 1024
STROKE = 112
LEFT_ARM = [(300, 306), (512, 718)]
RIGHT_ARM = [(512, 718), (724, 306)]

AMBER_TOP = (0xFF, 0xD2, 0x70)
AMBER_BOTTOM = (0xF0, 0x9A, 0x30)
CREAM_TOP = (0xFF, 0xF8, 0xEB)
CREAM_BOTTOM = (0xFB, 0xE7, 0xC6)
OVERLAP = (0xFF, 0xE0, 0xA0)

BG_CENTER = (0x2B, 0x24, 0x18)
BG_MID = (0x12, 0x12, 0x16)
BG_EDGE = (0x0A, 0x0A, 0x0C)
INK = "#0A0A0C"

SUPERSAMPLE = 4


MARK_TOP = LEFT_ARM[0][1] - STROKE / 2
MARK_BOTTOM = LEFT_ARM[1][1] + STROKE / 2


# --- Raster helpers ----------------------------------------------------------


def _stroke_mask(size: int, points, scale: float) -> Image.Image:
    """Round-capped, round-joined polyline as an L mask, centred on [size]."""
    big = size * SUPERSAMPLE
    factor = big / CANVAS * scale
    offset = big * (1 - scale) / 2
    pts = [(x * factor + offset, y * factor + offset) for x, y in points]
    width = STROKE * factor
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.line(pts, fill=255, width=round(width), joint="curve")
    radius = width / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def _vertical_gradient(size: int, top, bottom, scale: float) -> Image.Image:
    """Gradient spanning the mark's own height, so it reads the same at any
    scale."""
    image = Image.new("RGB", (size, size))
    span_top = MARK_TOP / CANVAS
    span_bottom = MARK_BOTTOM / CANVAS
    for row in range(size):
        # Map the row back into 1024-unit mark space.
        unit = ((row / size) - (1 - scale) / 2) / scale
        t = min(1.0, max(0.0, (unit - span_top) / (span_bottom - span_top)))
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        ImageDraw.Draw(image).line([(0, row), (size, row)], fill=color)
    return image


def mark(size: int, scale: float = 1.0, monochrome: bool = False) -> Image.Image:
    """The mark alone on transparency."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    left = _stroke_mask(size, LEFT_ARM, scale)
    right = _stroke_mask(size, RIGHT_ARM, scale)

    if monochrome:
        out.paste((255, 255, 255, 255), (0, 0), ImageChops.lighter(left, right))
        return out

    for mask, top, bottom in (
        (left, AMBER_TOP, AMBER_BOTTOM),
        (right, CREAM_TOP, CREAM_BOTTOM),
    ):
        layer = _vertical_gradient(size, top, bottom, scale).convert("RGBA")
        layer.putalpha(mask)
        out.alpha_composite(layer)
    overlap = Image.new("RGBA", (size, size), OVERLAP + (255,))
    overlap.putalpha(ImageChops.multiply(left, right))
    out.alpha_composite(overlap)
    return out


def background(size: int) -> Image.Image:
    """Warm radial glow behind the mark, falling off to ink."""
    big = size
    image = Image.new("RGB", (big, big), BG_EDGE)
    cx, cy = big * 0.5, big * 0.36
    max_r = big * 0.78
    pixels = image.load()
    for y in range(big):
        for x in range(big):
            t = min(1.0, ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / max_r)
            if t < 0.6:
                k = t / 0.6
                c = tuple(round(a + (b - a) * k) for a, b in zip(BG_CENTER, BG_MID))
            else:
                k = (t - 0.6) / 0.4
                c = tuple(round(a + (b - a) * k) for a, b in zip(BG_MID, BG_EDGE))
            pixels[x, y] = c
    return image


def icon(size: int, mark_scale: float, rounded: bool) -> Image.Image:
    bg = background(size).convert("RGBA")
    bg.alpha_composite(mark(size, mark_scale))
    if not rounded:
        return bg.convert("RGB")
    big = size * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=round(big * 0.225), fill=255
    )
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask.resize((size, size), Image.LANCZOS))
    return out


# --- SVG masters ---------------------------------------------------------------


def _svg_polyline(points, extra: str) -> str:
    pts = " ".join(f"{x},{y}" for x, y in points)
    return (
        f'<polyline points="{pts}" fill="none" stroke-width="{STROKE}" '
        f'stroke-linecap="round" stroke-linejoin="round" {extra}/>'
    )


def svg(with_background: bool) -> str:
    def hexc(c):
        return "#%02X%02X%02X" % c

    def gradient(name, top, bottom):
        return (
            f'<linearGradient id="{name}" x1="0" y1="{MARK_TOP}" x2="0" '
            f'y2="{MARK_BOTTOM}" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{hexc(top)}"/>'
            f'<stop offset="1" stop-color="{hexc(bottom)}"/></linearGradient>'
        )

    defs = (
        gradient("amber", AMBER_TOP, AMBER_BOTTOM)
        + gradient("cream", CREAM_TOP, CREAM_BOTTOM)
        # Where the arms cross: the right arm, masked to the left arm.
        + '<mask id="left" maskUnits="userSpaceOnUse" x="0" y="0" '
        'width="1024" height="1024">'
        + _svg_polyline(LEFT_ARM, 'stroke="#FFFFFF"')
        + "</mask>"
    )
    bg = ""
    if with_background:
        defs += (
            '<radialGradient id="glow" cx="512" cy="368" r="800" '
            'gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{hexc(BG_CENTER)}"/>'
            f'<stop offset="0.6" stop-color="{hexc(BG_MID)}"/>'
            f'<stop offset="1" stop-color="{hexc(BG_EDGE)}"/></radialGradient>'
        )
        bg = '<rect width="1024" height="1024" rx="230" fill="url(#glow)"/>'
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        "<title>Veylora</title>"
        f"<defs>{defs}</defs>{bg}"
        + _svg_polyline(LEFT_ARM, 'stroke="url(#amber)"')
        + _svg_polyline(RIGHT_ARM, 'stroke="url(#cream)"')
        + _svg_polyline(RIGHT_ARM, f'stroke="{hexc(OVERLAP)}" mask="url(#left)"')
        + "</svg>\n"
    )


# --- Writers -------------------------------------------------------------------


def save(image: Image.Image, *parts: str) -> None:
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def write_text(text: str, *parts: str) -> None:
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", os.path.relpath(path, ROOT))


def main() -> None:
    # Masters and in-app mark.
    write_text(svg(False), "assets", "branding", "veylora_mark.svg")
    write_text(svg(True), "assets", "branding", "veylora_icon.svg")
    for factor, folder in ((1, ""), (2, "2.0x"), (3, "3.0x")):
        parts = ["assets", "branding"] + ([folder] if folder else []) + ["veylora_mark.png"]
        save(mark(64 * factor), *parts)
    save(icon(256, 0.86, rounded=True), "assets", "branding", "veylora_icon_256.png")

    # Android: legacy icons (pre-API 26) carry their own rounded shape.
    res = ("android", "app", "src", "main", "res")
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        save(icon(px, 0.84, rounded=True), *res, f"mipmap-{density}", "ic_launcher.png")

    # Android adaptive layers are 108dp; keep the mark inside the 66dp safe
    # circle so no launcher mask clips it.
    adaptive = {k: round(v * 108 / 48) for k, v in legacy.items()}
    for density, px in adaptive.items():
        save(background(px), *res, f"mipmap-{density}", "ic_launcher_background.png")
        save(mark(px, 0.72), *res, f"mipmap-{density}", "ic_launcher_foreground.png")
        save(mark(px, 0.72, monochrome=True), *res, f"mipmap-{density}", "ic_launcher_monochrome.png")
    write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n",
        *res, "mipmap-anydpi-v26", "ic_launcher.xml",
    )

    # Android launch screen mark (96dp).
    for density, px in {"mdpi": 96, "hdpi": 144, "xhdpi": 192, "xxhdpi": 288, "xxxhdpi": 384}.items():
        save(mark(px), *res, f"drawable-{density}", "launch_mark.png")

    # iOS AppIcon: every size in Contents.json, opaque.
    iconset = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    with open(os.path.join(iconset, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    master = icon(1024, 0.86, rounded=False)
    done = set()
    for entry in contents["images"]:
        name = entry["filename"]
        if name in done:
            continue
        done.add(name)
        points = float(entry["size"].split("x")[0])
        px = round(points * float(entry["scale"].rstrip("x")))
        image = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
        save(image, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", name)

    # iOS launch image (120pt mark).
    for suffix, factor in (("", 1), ("@2x", 2), ("@3x", 3)):
        save(
            mark(120 * factor),
            "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset", f"LaunchImage{suffix}.png",
        )


if __name__ == "__main__":
    main()
