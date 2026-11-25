# Launch Screen Assets

Generated, not hand-placed. `LaunchImage*.png` is the home screen's resting dial, and
`LaunchImage-dark*.png` its twin for the dark appearance, rendered from the app's own
`LaunchDial` widget — the one the app draws over its first frames and carries into the
home dial, so the launch and what takes over from it are one drawing. Re-render rather
than dropping images in here:

```sh
flutter test tool/splash/render_launch_dial_test.dart
```

`Contents.json` and the `LaunchBackground` colour set beside this one are written by
`tool/app_icon/generate_icons.py`. `ios/Runner/Base.lproj/LaunchScreen.storyboard`
carries the image's point size, which is `AppLayout.launchShownCircle`.
