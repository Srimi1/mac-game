# Break the Quiet Days

<p align="center">
  <img src="Brand/BreakTheQuietDaysLogo.png" width="220" alt="Break the Quiet Days neon ball-and-block logo">
</p>

[![macOS CI](https://github.com/Srimi1/mac-game/actions/workflows/ci.yml/badge.svg)](https://github.com/Srimi1/mac-game/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Srimi1/mac-game)](https://github.com/Srimi1/mac-game/releases/latest)
[![License](https://img.shields.io/github/license/Srimi1/mac-game)](LICENSE)

A native neon-retro Breakout game for Apple Silicon Macs. Restore color and music to 24 handcrafted rooms across eight quiet days.

## Download and play

Download the latest ready-to-play build from [GitHub Releases](https://github.com/Srimi1/mac-game/releases/latest).

Requirements: an Apple Silicon Mac (M1 or newer) running macOS 14 Sonoma or later.

1. Download and unzip `Break-the-Quiet-Days-*-macOS-Apple-Silicon.zip`.
2. Drag **Break the Quiet Days.app** into Applications.
3. On the first launch, Control-click the app, choose **Open**, then confirm **Open**.

The community build is ad-hoc signed and is not Apple-notarized yet, so opening it normally for the first time may show a security warning. The Control-click flow lets macOS record your approval. After that, the app opens normally.

## What is new in 1.2

- **Precision physics:** stable rebound angles, anti-stall correction, shape-matched collision paths, and level-aware speed progression.
- **Adjustable launch aiming:** drag from the waiting ball and release, use Left/Right before launch, or aim with a controller's right stick.
- **Neon game pieces:** generated skins for every brick silhouette, the energy ball, and the hover-launch paddle, while native SpriteKit paths continue to own all collisions.
- **24 richer layouts:** offset formations, negative-space channels, mixed durability, movement groups, and indestructible cyan obstacles from Day 3 onward.
- **Eight synthwave worlds:** one generated environment per day with runtime overlays, parallax, scanlines, and particles.
- **Sunshift:** after the first three gentle rooms, levels have two phases. Clear the pale shapes first; the ball then turns bright yellow and can hit only the yellow bars marked with a ☀ glyph.
- **Five brick silhouettes:** rounded tiles, capsules, diamonds, hexagons, and triangles use matching lightweight collision geometry.

### Controls

- Move the paddle: trackpad/mouse, **A / D**, or a controller's left stick
- Aim before launch: drag from the ball, **Left / Right**, or the controller's right stick
- Launch: release the drag, press **Space**, or controller **A**
- Pause: **Escape** or controller **Menu**
- Full screen: **Control-Command-F**

Trajectory preview, music/effect volume, screen shake, and reduced-motion options are available in Settings.

## Build from source

The committed Xcode project is ready to build; XcodeGen is only needed after changing `project.yml`.

```sh
xcodebuild \
  -project BreakTheQuietDays.xcodeproj \
  -scheme BreakTheQuietDays \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -only-testing:BreakTheQuietDaysTests \
  test
```

Create the same release archive published on GitHub with:

```sh
Scripts/package_release.sh 1.2.0
```

The resulting ZIP and SHA-256 checksum are written to `dist/`.

## Privacy, contributing, and support

The game is fully offline. Progress and settings stay on the Mac in UserDefaults; there are no accounts, analytics, ads, or network requests. Generated artwork is decorative—gameplay geometry and physics are native and deterministic.

Bug reports and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing and [SECURITY.md](SECURITY.md) for responsible vulnerability reporting. The project is available under the [Apache License 2.0](LICENSE).
