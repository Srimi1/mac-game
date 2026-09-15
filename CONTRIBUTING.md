# Contributing

Thanks for helping improve Break the Quiet Days.

## Before opening a pull request

1. Use macOS 14 or later with a current Xcode release.
2. Create a focused branch from `main`.
3. Keep generated artwork decorative. SpriteKit paths must remain the source of truth for rendering and collision geometry.
4. Preserve the 24 existing level IDs and persisted UserDefaults keys unless a migration is included.
5. Run the unit and scene tests:

   ```sh
   xcodebuild \
     -project BreakTheQuietDays.xcodeproj \
     -scheme BreakTheQuietDays \
     -configuration Debug \
     -derivedDataPath DerivedData \
     -only-testing:BreakTheQuietDaysTests \
     test
   ```

6. Build Release separately:

   ```sh
   xcodebuild \
     -project BreakTheQuietDays.xcodeproj \
     -scheme BreakTheQuietDays \
     -configuration Release \
     -derivedDataPath DerivedData \
     ARCHS=arm64 \
     CODE_SIGNING_ALLOWED=NO \
     build
   ```

## Pull requests

Describe the player-visible change, the tests you ran, and any performance or accessibility impact. Include before/after screenshots for visual changes. Do not commit DerivedData, release archives, signing credentials, or personal provisioning profiles.

By contributing, you agree that your contribution is licensed under Apache License 2.0.
