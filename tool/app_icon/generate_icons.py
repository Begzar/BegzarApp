#!/usr/bin/env python3
"""Render the Begzar launcher icon and store assets for every platform.

Source of truth for the artwork is `bird_source.png` next to this script —
the blue-accent bird cut out onto transparency. The script composes it over
a light field, derives the white silhouette used by Android themed icons
and the VPN notification, writes iOS 18 dark/tinted catalog slots plus an
Icon Composer `.icon` for iOS 26, the bird the app draws on its own screens,
and writes the Play Store assets. Run
from the repo root after changing the artwork or any constant below:

    python3 tool/app_icon/generate_icons.py [--preview out.png]

Requires Pillow and numpy.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# --- Treatment -------------------------------------------------------------
# Flat light field, barely graded for depth; the artwork carries the rest.
FIELD_ANGLE_DEG = 180.0
FIELD_TOP = (0xF4, 0xF4, 0xF5)
FIELD_BOTTOM = (0xE6, 0xE6, 0xEA)
# Dark appearance inverts the field so the white bird reads.
DARK_FIELD_TOP = tuple(255 - c for c in FIELD_TOP)
DARK_FIELD_BOTTOM = tuple(255 - c for c in FIELD_BOTTOM)

# Largest bird dimension relative to a full-bleed tile. Keeps wing and tail
# tips clear of circle and squircle masks.
BIRD_TILE_RATIO = 0.74
# Themed-icon (monochrome) glyph inside the adaptive canvas safe zone.
MONO_CANVAS_RATIO = 0.66
# Notification silhouette inside its square (Android wants generous padding).
NOTIF_RATIO = 0.86
# Alpha band converted to the hard silhouette edge.
SILHOUETTE_EDGE = (0.35, 0.65)

ADAPTIVE_VISIBLE = 72.0 / 108.0
MASTER_SIZE = 1024
MACOS_CONTENT_RATIO = 824.0 / 1024.0  # Apple icon grid
SQUIRCLE_RADIUS_RATIO = 0.2237
SUPERSAMPLE = 4

ANDROID_DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
LEGACY_BASE_DP = 48
ADAPTIVE_BASE_DP = 108
NOTIF_SIZE = 192


# iOS 18 catalog: one 1024 square per appearance.
IOS_APP_ICON = "AppIcon.png"
IOS_APP_ICON_DARK = "AppIcon-dark.png"
IOS_APP_ICON_TINTED = "AppIcon-tinted.png"
MACOS_SIZES = (16, 32, 64, 128, 256, 512, 1024)
WEB_SIZES = (192, 512)
FAVICON_SIZE = 16
ICO_SIZES = (16, 24, 32, 48, 64, 72, 96, 128, 256)

# --- Native splash ---------------------------------------------------------
# The launch window both platforms paint before Flutter draws a frame: the
# app's own page with the resting dial on it, in the appearance the phone is
# in. The dial is rendered by tool/splash/render_launch_dial_test.dart; this
# script writes only the ground and the iOS catalog entries around it.

# The page the first Flutter frame paints in each theme — `AppPalette.light`
# and `AppPalette.dark`'s `page` — so the handover is not a change of colour.
# Android names them again in values/colors.xml and values-night/colors.xml,
# because nothing in Dart can reach a window drawn before Dart runs;
# test/architecture/launch_window_colours_test.dart holds both to the palette.
SPLASH_GROUND_DAY = (0xE2, 0xE7, 0xEE)
SPLASH_GROUND_NIGHT = (0x0A, 0x0D, 0x12)
IOS_LAUNCH_BACKGROUND = "LaunchBackground"
IOS_LAUNCH_IMAGE = "LaunchImage"

# The bird the app draws on its own screens, by height: the artwork is taller
# than it is wide. Large enough that the home dial never scales it up on a
# dense screen.
IN_APP_MARK_HEIGHT = 640
IN_APP_MARK = "assets/images/bird_mark.png"
IN_APP_ACCENT = "assets/images/bird_accent.png"

PLAY_ICON_SIZE = 512
FEATURE_SIZE = (1024, 500)
FEATURE_NAME = "Begzar"
FEATURE_FONT = "assets/fonts/Poppins-SemiBold.ttf"
FEATURE_TEXT_COLOR = (0x1B, 0x1A, 0x20)
FEATURE_ACCENT = (0x17, 0x6D, 0xB4)  # the wing streak blue


def coords(width: int, height: int) -> tuple[np.ndarray, np.ndarray]:
    xs = (np.arange(width, dtype=np.float64) + 0.5) / width
    ys = (np.arange(height, dtype=np.float64) + 0.5) / height
    return np.meshgrid(xs, ys)


def linear_gradient_t(x: np.ndarray, y: np.ndarray, angle_deg: float) -> np.ndarray:
    """CSS linear-gradient position (0deg points up, clockwise)."""
    rad = math.radians(angle_deg)
    sin, cos = math.sin(rad), math.cos(rad)
    length = abs(sin) + abs(cos)
    return 0.5 + ((x - 0.5) * sin + (y - 0.5) * -cos) / length


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def field_rgb(
    width: int,
    height: int,
    top: tuple[int, int, int] = FIELD_TOP,
    bottom: tuple[int, int, int] = FIELD_BOTTOM,
) -> np.ndarray:
    x, y = coords(width, height)
    t = np.clip(linear_gradient_t(x, y, FIELD_ANGLE_DEG), 0.0, 1.0)[..., None]
    return (1.0 - t) * np.array(top, dtype=np.float64) + t * np.array(bottom, dtype=np.float64)


def accent_mask(rgba: np.ndarray) -> np.ndarray:
    """The two blue streaks: saturated pixels whose dominant channel is blue."""
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    chroma = rgb.max(axis=-1) - rgb.min(axis=-1)
    return (alpha > 32) & (blue > red + 20) & (blue > green) & (chroma > 40)


def treated_rgba(rgba: np.ndarray, treatment: str | None) -> np.ndarray:
    """Keep bird detail and the blue streaks; invert or gray only the body."""
    if treatment is None:
        return rgba
    out = rgba.copy()
    rgb = out[..., :3]
    body = (out[..., 3] > 8) & ~accent_mask(rgba)
    if treatment == "invert":
        rgb[body] = 255.0 - rgb[body]
    elif treatment == "gray":
        y = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
        for channel in range(3):
            rgb[..., channel] = np.where(body, y, rgb[..., channel])
    else:
        raise ValueError(f"unknown treatment {treatment!r}")
    return out


class Bird:
    """The cut-out artwork plus its tight bounding box."""

    def __init__(self, path: Path):
        image = Image.open(path).convert("RGBA")
        self.rgba = np.asarray(image, dtype=np.float64)
        alpha = self.rgba[..., 3]
        rows = np.flatnonzero(alpha.max(axis=1) > 8)
        cols = np.flatnonzero(alpha.max(axis=0) > 8)
        self.bbox = (cols[0], rows[0], cols[-1] + 1, rows[-1] + 1)

    def _sprite(self, rgba: np.ndarray, target_max: int) -> Image.Image:
        """Crop to bbox and scale so max(w, h) == target_max."""
        left, top, right, bottom = self.bbox
        crop = Image.fromarray(np.round(rgba).astype(np.uint8), "RGBA").crop(self.bbox)
        ratio = target_max / max(right - left, bottom - top)
        size = (max(1, round(crop.width * ratio)), max(1, round(crop.height * ratio)))
        return crop.resize(size, Image.LANCZOS)

    def scaled(self, target_max: int, treatment: str | None = None) -> Image.Image:
        """Bird cropped to its bbox and scaled so max(w, h) == target_max."""
        return self._sprite(treated_rgba(self.rgba, treatment), target_max)

    def accent(self, target_max: int) -> Image.Image:
        """Only the two blue streaks, aligned with `scaled`."""
        rgba = np.zeros_like(self.rgba)
        mask = accent_mask(self.rgba)
        rgba[mask] = self.rgba[mask]
        return self._sprite(rgba, target_max)

    def silhouette(self, target_max: int) -> Image.Image:
        """White bird on transparency, hard-edged, scaled like `scaled`."""
        alpha = smoothstep(*SILHOUETTE_EDGE, self.rgba[..., 3] / 255.0) * 255.0
        white = np.dstack((np.full_like(alpha, 255.0),) * 3 + (alpha,))
        return self._sprite(white, target_max)


def paste_centered(canvas: Image.Image, sprite: Image.Image) -> None:
    canvas.paste(
        sprite,
        ((canvas.width - sprite.width) // 2, (canvas.height - sprite.height) // 2),
        sprite,
    )


def composed_tile(
    bird: Bird,
    size: int,
    *,
    field_top: tuple[int, int, int] = FIELD_TOP,
    field_bottom: tuple[int, int, int] = FIELD_BOTTOM,
    treatment: str | None = None,
) -> Image.Image:
    """Full-bleed opaque tile: treated bird over a field, blue streaks on top."""
    tile = Image.fromarray(
        np.round(field_rgb(size, size, field_top, field_bottom)).astype(np.uint8), "RGB"
    ).convert("RGBA")
    target = round(size * BIRD_TILE_RATIO)
    paste_centered(tile, bird.scaled(target, treatment))
    if treatment is not None:
        paste_centered(tile, bird.accent(target))
    return tile.convert("RGB")


def circle_mask(size: int) -> Image.Image:
    big = size * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def squircle_mask(size: int, content: int) -> Image.Image:
    big, big_content = size * SUPERSAMPLE, content * SUPERSAMPLE
    offset = (big - big_content) // 2
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (offset, offset, offset + big_content - 1, offset + big_content - 1),
        radius=round(big_content * SQUIRCLE_RADIUS_RATIO),
        fill=255,
    )
    return mask.resize((size, size), Image.LANCZOS)


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"  wrote {path}")


def srgb_color(rgb: tuple[int, int, int]) -> str:
    r, g, b = (c / 255.0 for c in rgb)
    return f"extended-srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def appearance(value: str) -> list[dict[str, str]]:
    return [{"appearance": "luminosity", "value": value}]


def ios_catalog_slot(filename: str, appearance_value: str | None = None) -> dict:
    entry: dict = {}
    if appearance_value:
        entry["appearances"] = appearance(appearance_value)
    entry.update({
        "filename": filename,
        "idiom": "universal",
        "platform": "ios",
        "size": "1024x1024",
    })
    return entry


def write_ios_contents(ios_dir: Path) -> None:
    """Single-size 1024 catalog: default, dark (white bird), tinted (gray bird + blue)."""
    images = [
        ios_catalog_slot(IOS_APP_ICON),
        ios_catalog_slot(IOS_APP_ICON_DARK, "dark"),
        ios_catalog_slot(IOS_APP_ICON_TINTED, "tinted"),
    ]
    path = ios_dir / "Contents.json"
    path.write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"  wrote {path}")


def launch_image_name(suffix: str, scale: int) -> str:
    return f"{IOS_LAUNCH_IMAGE}{suffix}{'' if scale == 1 else f'@{scale}x'}.png"


def write_launch_image_contents(launch_dir: Path) -> None:
    """The launch mark at three scales, with a dark-appearance twin of each."""
    images = []
    for suffix, appearance_value in (("", None), ("-dark", "dark")):
        for scale in (1, 2, 3):
            entry: dict = {}
            if appearance_value:
                entry["appearances"] = appearance(appearance_value)
            entry.update({
                "filename": launch_image_name(suffix, scale),
                "idiom": "universal",
                "scale": f"{scale}x",
            })
            images.append(entry)
    path = launch_dir / "Contents.json"
    path.write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"  wrote {path}")


def write_launch_background(colorset_dir: Path) -> None:
    """The launch window's ground: the light page, and the dark one in dark."""

    def colour(rgb: tuple[int, int, int], appearance_value: str | None) -> dict:
        entry: dict = {}
        if appearance_value:
            entry["appearances"] = appearance(appearance_value)
        red, green, blue = (f"0x{channel:02X}" for channel in rgb)
        entry.update({
            "color": {
                "color-space": "srgb",
                "components": {"alpha": "1.000", "blue": blue, "green": green, "red": red},
            },
            "idiom": "universal",
        })
        return entry

    colors = [colour(SPLASH_GROUND_DAY, None), colour(SPLASH_GROUND_NIGHT, "dark")]
    colorset_dir.mkdir(parents=True, exist_ok=True)
    path = colorset_dir / "Contents.json"
    path.write_text(json.dumps({"colors": colors, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"  wrote {path}")


def write_icon_composer(repo: Path, bird: Bird) -> None:
    """Layered .icon: body variants + a blue-accent layer that never recolors."""
    icon_dir = repo / "ios/Runner/AppIcon.icon"
    assets = icon_dir / "Assets"
    target = round(MASTER_SIZE * BIRD_TILE_RATIO)

    def layer(name: str, treatment: str | None = None) -> None:
        canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
        paste_centered(canvas, bird.scaled(target, treatment))
        save_png(canvas, assets / name)

    layer("bird.png")
    layer("bird-dark.png", "invert")
    layer("bird-tinted.png", "gray")
    accent = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    paste_centered(accent, bird.accent(target))
    save_png(accent, assets / "bird-accent.png")

    light = {"linear-gradient": [srgb_color(FIELD_TOP), srgb_color(FIELD_BOTTOM)]}
    dark = {"linear-gradient": [srgb_color(DARK_FIELD_TOP), srgb_color(DARK_FIELD_BOTTOM)]}
    document = {
        "fill-specializations": [
            {"value": light},
            {"appearance": "dark", "value": dark},
        ],
        "groups": [
            {
                "name": "Bird",
                "layers": [
                    {
                        "name": "Body",
                        "glass": False,
                        "image-name-specializations": [
                            {"value": "bird.png"},
                            {"appearance": "dark", "value": "bird-dark.png"},
                            {"appearance": "tinted", "value": "bird-tinted.png"},
                        ],
                    },
                    {
                        "name": "Accent",
                        "glass": False,
                        "image-name": "bird-accent.png",
                    },
                ],
                "shadow": {"kind": "none", "opacity": 0},
                "specular": False,
                "translucency": {"enabled": False, "value": 0},
            }
        ],
        "supported-platforms": {"squares": ["iOS"]},
    }
    path = icon_dir / "icon.json"
    path.write_text(json.dumps(document, indent=2) + "\n")
    print(f"  wrote {path}")


def write_in_app_marks(repo: Path, bird: Bird) -> None:
    """The in-app bird as two layers: the dark-appearance body, and its streaks.

    Both are cut from the same box and scaled by the same factor, so the app
    can draw the streaks over the body on their own and they land exactly on
    the body's.
    """
    save_png(bird.scaled(IN_APP_MARK_HEIGHT, treatment="invert"), repo / IN_APP_MARK)
    save_png(bird.accent(IN_APP_MARK_HEIGHT), repo / IN_APP_ACCENT)


def feature_graphic(bird: Bird, repo: Path) -> Image.Image:
    width, height = FEATURE_SIZE
    canvas = Image.fromarray(np.round(field_rgb(width, height)).astype(np.uint8), "RGB").convert("RGBA")

    sprite = bird.scaled(round(height * 0.86))
    canvas.paste(sprite, (width - sprite.width - 60, (height - sprite.height) // 2), sprite)

    font = ImageFont.truetype(str(repo / FEATURE_FONT), size=130)
    draw = ImageDraw.Draw(canvas)
    text_box = draw.textbbox((0, 0), FEATURE_NAME, font=font)
    text_x, text_y = 80, (height - (text_box[3] - text_box[1])) // 2 - text_box[1] - 14
    draw.text((text_x, text_y), FEATURE_NAME, font=font, fill=FEATURE_TEXT_COLOR)

    bar_y = text_y + text_box[3] + 26
    draw.rounded_rectangle(
        (text_x + 4, bar_y, text_x + 4 + 210, bar_y + 12), radius=6, fill=FEATURE_ACCENT
    )
    return canvas.convert("RGB")


def generate(repo: Path, preview: Path | None) -> None:
    bird = Bird(Path(__file__).resolve().parent / "bird_source.png")
    res = repo / "android/app/src/main/res"
    master = composed_tile(bird, MASTER_SIZE)

    # Android legacy launcher: circle-cropped tile.
    for density, factor in ANDROID_DENSITIES.items():
        size = round(LEGACY_BASE_DP * factor)
        tile = master.resize((size, size), Image.LANCZOS).convert("RGBA")
        tile.putalpha(circle_mask(size))
        save_png(tile, res / f"mipmap-{density}/ic_launcher.png")

    # Android adaptive layers: launchers crop the center 72/108 of the canvas.
    adaptive_master = round(ADAPTIVE_BASE_DP * ANDROID_DENSITIES["xxxhdpi"])
    visible = round(adaptive_master * ADAPTIVE_VISIBLE)
    bg_master = Image.fromarray(
        np.round(field_rgb(adaptive_master, adaptive_master)).astype(np.uint8), "RGB"
    )
    fg_master = Image.new("RGBA", (adaptive_master, adaptive_master), (0, 0, 0, 0))
    paste_centered(fg_master, bird.scaled(round(visible * BIRD_TILE_RATIO)))
    mono_master = Image.new("RGBA", (adaptive_master, adaptive_master), (0, 0, 0, 0))
    paste_centered(mono_master, bird.silhouette(round(adaptive_master * MONO_CANVAS_RATIO)))
    for density, factor in ANDROID_DENSITIES.items():
        size = round(ADAPTIVE_BASE_DP * factor)
        save_png(bg_master.resize((size, size), Image.LANCZOS), res / f"mipmap-{density}/ic_launcher_background.png")
        save_png(fg_master.resize((size, size), Image.LANCZOS), res / f"mipmap-{density}/ic_launcher_foreground.png")
        save_png(mono_master.resize((size, size), Image.LANCZOS), res / f"mipmap-{density}/ic_launcher_monochrome.png")

    # Native splash: only its ground and the iOS catalog entries. The mark is
    # the home screen's resting dial, rendered from the app's own widget by
    # tool/splash/render_launch_dial_test.dart into the files listed here.
    assets = repo / "ios/Runner/Assets.xcassets"
    write_launch_image_contents(assets / f"{IOS_LAUNCH_IMAGE}.imageset")
    write_launch_background(assets / f"{IOS_LAUNCH_BACKGROUND}.colorset")

    # VPN notification silhouette (white on transparency, generous padding).
    notif = Image.new("RGBA", (NOTIF_SIZE, NOTIF_SIZE), (0, 0, 0, 0))
    paste_centered(notif, bird.silhouette(round(NOTIF_SIZE * NOTIF_RATIO)))
    save_png(notif, res / "drawable/ic_vpn.png")

    # iOS: one 1024 square per appearance; actool derives the rest.
    # Dark: white 3D bird on the inverted field. Tinted: gray 3D bird on the
    # light field so the system tints the glyph. Both keep the blue streaks.
    ios_dir = repo / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    dark_master = composed_tile(
        bird, MASTER_SIZE, field_top=DARK_FIELD_TOP, field_bottom=DARK_FIELD_BOTTOM, treatment="invert"
    )
    tinted_master = composed_tile(bird, MASTER_SIZE, treatment="gray")
    save_png(master, ios_dir / IOS_APP_ICON)
    save_png(dark_master, ios_dir / IOS_APP_ICON_DARK)
    save_png(tinted_master, ios_dir / IOS_APP_ICON_TINTED)
    write_ios_contents(ios_dir)
    expected = {"Contents.json", IOS_APP_ICON, IOS_APP_ICON_DARK, IOS_APP_ICON_TINTED}
    for stale in ios_dir.iterdir():
        if stale.name not in expected:
            stale.unlink()
            print(f"  removed {stale}")
    write_icon_composer(repo, bird)

    write_in_app_marks(repo, bird)

    # macOS: tile inset on the Apple icon grid with a baked squircle.
    macos_dir = repo / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    content = round(MASTER_SIZE * MACOS_CONTENT_RATIO)
    mac_master = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    mac_master.paste(master.resize((content, content), Image.LANCZOS), ((MASTER_SIZE - content) // 2,) * 2)
    mac_master.putalpha(squircle_mask(MASTER_SIZE, content))
    for size in MACOS_SIZES:
        save_png(mac_master.resize((size, size), Image.LANCZOS), macos_dir / f"app_icon_{size}.png")

    # Web + favicon: full-bleed squares (maskable safe zone holds the bird).
    for size in WEB_SIZES:
        tile = master.resize((size, size), Image.LANCZOS)
        save_png(tile, repo / f"web/icons/Icon-{size}.png")
        save_png(tile, repo / f"web/icons/Icon-maskable-{size}.png")
    save_png(master.resize((FAVICON_SIZE,) * 2, Image.LANCZOS), repo / "web/favicon.png")

    # Windows: multi-size ICO consumed by the runner and the system tray.
    ico_path = repo / "windows/runner/resources/app_icon.ico"
    master.resize((256, 256), Image.LANCZOS).save(ico_path, sizes=[(s, s) for s in ICO_SIZES])
    print(f"  wrote {ico_path}")

    # Store assets.
    save_png(master.resize((PLAY_ICON_SIZE,) * 2, Image.LANCZOS), repo / "store/play_icon_512.png")
    save_png(feature_graphic(bird, repo), repo / "store/feature_graphic_1024x500.png")

    if preview:
        checker = Image.new("RGB", (192, 192), (150, 150, 150))
        fg_prev = checker.copy()
        fg_prev.paste(fg_master.resize((192, 192), Image.LANCZOS), (0, 0), fg_master.resize((192, 192), Image.LANCZOS))
        mono_prev = Image.new("RGB", (192, 192), (40, 44, 60))
        mono_prev.paste(mono_master.resize((192, 192), Image.LANCZOS), (0, 0), mono_master.resize((192, 192), Image.LANCZOS))
        notif_prev = Image.new("RGB", (192, 192), (40, 44, 60))
        notif_prev.paste(notif.resize((192, 192), Image.LANCZOS), (0, 0), notif.resize((192, 192), Image.LANCZOS))
        legacy = master.resize((192, 192), Image.LANCZOS).convert("RGBA")
        legacy.putalpha(circle_mask(192))
        legacy_prev = Image.new("RGB", (192, 192), (150, 150, 150))
        legacy_prev.paste(legacy, (0, 0), legacy)
        small = master.resize((48, 48), Image.LANCZOS).resize((192, 192), Image.NEAREST)
        cells = [
            master.resize((192, 192), Image.LANCZOS),
            dark_master.resize((192, 192), Image.LANCZOS),
            tinted_master.resize((192, 192), Image.LANCZOS),
            legacy_prev,
            fg_prev,
            mono_prev,
            notif_prev,
            small,
        ]
        pad, cell = 12, 192
        sheet = Image.new("RGB", (len(cells) * (cell + pad) + pad, cell + 2 * pad), (100, 100, 100))
        for i, img in enumerate(cells):
            sheet.paste(img, (pad + i * (cell + pad), pad))
        feature = feature_graphic(bird, repo).resize((1024 // 2, 500 // 2), Image.LANCZOS)
        full = Image.new("RGB", (sheet.width, sheet.height + feature.height + pad), (100, 100, 100))
        full.paste(sheet, (0, 0))
        full.paste(feature, (pad, sheet.height))
        full.save(preview)
        print(f"  wrote preview {preview}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--preview", type=Path, default=None)
    args = parser.parse_args()
    generate(args.repo_root, args.preview)


if __name__ == "__main__":
    main()
