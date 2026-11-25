# App icon generator

`generate_icons.py` renders the launcher icon — the blue-accent bird over a
flat light field — plus the store assets, for every platform target in this
repo:

| Target | Files |
| --- | --- |
| Android legacy (< API 26) | `mipmap-*/ic_launcher.png` (circle-cropped) |
| Android adaptive | `mipmap-*/ic_launcher_background.png`, `mipmap-*/ic_launcher_foreground.png` |
| Android themed (13+) | `mipmap-*/ic_launcher_monochrome.png` (white silhouette) |
| Android notification | `drawable/ic_vpn.png` (white silhouette, padded) |
| Native splash | `LaunchBackground.colorset`, `LaunchImage.imageset/Contents.json` (the images themselves come from `tool/splash/`, below) |
| iOS | `AppIcon.appiconset/AppIcon.png`, `AppIcon-dark.png`, `AppIcon-tinted.png` |
| iOS 26 | `ios/Runner/AppIcon.icon` (Icon Composer; field + bird layers) |
| macOS | `AppIcon.appiconset/app_icon_*.png` (Apple-grid squircle baked in) |
| Web | `web/favicon.png`, `web/icons/Icon-*.png` |
| Windows | `windows/runner/resources/app_icon.ico` (also used by the tray) |
| In-app mark | `assets/images/bird_mark.png`, `assets/images/bird_accent.png` |
| Google Play | `store/play_icon_512.png`, `store/feature_graphic_1024x500.png` |

The artwork has a single source of truth: `bird_source.png` in this
directory — the bird cut out onto transparency. Everything above, including
the themed-icon monochrome and the notification silhouette (both required
by Android to be white-on-transparent), derives from its alpha channel.
The feature graphic sets the app name in the repo's bundled Poppins.

The native splash comes in a day and a night version, picked by the platform from the
phone's appearance. Its mark is the home screen's resting dial, not drawn here: run
`flutter test tool/splash/render_launch_dial_test.dart` after changing the dial or the
palette. It renders the app's own `LaunchDial` widget — the one the launch cover draws
over the first frames and carries into the home dial — into `drawable-*/splash_bird.png`,
`drawable-night-*/splash_bird.png` and `LaunchImage*.png`. Android takes it on the 288dp
Android 12 icon canvas, of which only the inner circle is shown; the pre-12 launch
window centres the same file, which keeps the dial one size across OS versions. iOS
centres the bare dial with a constraint of its own.

The grounds are `SPLASH_GROUND_DAY` and `SPLASH_GROUND_NIGHT`, the app's light and dark
page. The script writes them into the iOS `LaunchBackground` colour set; Android names
them again in `values/colors.xml` and `values-night/colors.xml`.
`test/architecture/launch_window_colours_test.dart` fails if either platform drifts
from `AppPalette`, so change the palette, these constants and the Android colours
together.

iOS 18 home-screen appearances keep the 3D bird and the two blue streaks.
**Dark** inverts the body onto the inverted field (white bird, dark square).
**Tinted** is a Rec. 709 gray body on the light field so the system tints
the glyph, not the square; blue stays as a separate overlay. iOS 26 reads
`ios/Runner/AppIcon.icon` — body variants plus an accent layer that never
recolors. Glass is off on the glyph so the baked shading is not doubled.
Xcode compiles both the catalog and the `.icon`, and icon-stack fallback
generation is disabled so iOS 18 keeps the catalog rather than a flattened
`.icon`.

The in-app mark is the dark-appearance bird the home dial draws, written twice:
`bird_mark.png` is the whole bird, and `bird_accent.png` is only its two streaks,
cut from the same box. The dial takes its outline from the first and lights the
streaks from the second on their own, so the two files must come from the same
run.

Regenerate after changing the artwork or any treatment constant:

```sh
python3 -m pip install pillow numpy   # once
python3 tool/app_icon/generate_icons.py
```

`--preview sheet.png` additionally writes a contact sheet for eyeballing;
`--repo-root` overrides the output root (defaults to this checkout).
