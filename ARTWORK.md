# Neon environment artwork

The nine raster backdrops in `Sources/Resources/Assets.xcassets` were generated with the built-in OpenAI image generator for the 1.2 neon-retro redesign. `NeonDay01` through `NeonDay08` ship behind their matching campaign days; `NeonMenu` is used by the SwiftUI shell.

## Shared production prompt

- Use case: `stylized-concept`
- Asset type: wide macOS arcade-game environment backdrop
- Style: polished cinematic 2D synthwave concept art with crisp layered depth and restrained glow
- Composition: 16:9 landscape, broad low-detail near-black negative space across the central 70 percent and upper-middle playfield, with visual interest at the far edges and low horizon
- Palette: near-black, midnight violet, electric cyan, hot magenta, and one restrained day-specific accent
- Constraints: atmospheric environment only; no text, letters, logos, trademarks, watermark, UI, gameplay blocks, paddle, ball, or people
- Avoid: a busy center, pastel haze, photorealism, recognizable franchises, and excessive bloom

## Day subjects

1. A dark futuristic chamber opening toward a geometric neon dawn.
2. A rain observatory overlooking a cyan-and-violet city storm.
3. A midnight greenhouse with circuit-like vines and geometric blossoms.
4. A high sky deck with angular light ribbons above dark clouds.
5. A lantern corridor opening onto a magenta evening horizon.
6. A lunar sanctuary above a reflective plain with crescent structures.
7. A prism laboratory with crystalline machinery and spectral edge beams.
8. A monumental sunset terminal with a gold-magenta horizon.

The menu variation combines the shared architectural framing, striped sunset, and reflective cyan grid without introducing a ninth campaign identity.

## Gameplay artwork

The built-in OpenAI image generator also produced three transparent gameplay sources. They are decorative SpriteKit skins; the canonical `CGPath` geometry remains the source of truth for collision and layout.

- Block sheet: six front-on faces—rounded, capsule, diamond, hexagon, triangle, and armored obstacle—with smoked-glass cores, cyan/magenta edge light, restrained violet circuitry, consistent optical padding, and no text.
- Ball: one centered white-cyan energy orb with a cyan shell, magenta crescent, and small internal facets, designed to remain legible at 24–31 points.
- Paddle: one centered 6:1 graphite hover launcher with a cyan upper rail, magenta underglow, violet channel, armored end caps, and a centered ball cradle.

The optimized outputs ship as `NeonBrickRounded`, `NeonBrickCapsule`, `NeonBrickDiamond`, `NeonBrickHexagon`, `NeonBrickTriangle`, `NeonBrickObstacle`, `NeonBall`, and `NeonPaddle`. `Scripts/prepare_generated_gameplay_assets.swift` records the deterministic crop/downsample step used to create them from the generated source files.

Brick skins receive restrained runtime tinting and geometry details by progression tier: clean glass for Days 1–2, reinforced faces for Days 3–4, circuit framing for Days 5–6, and armored/prismatic marks for Days 7–8. Room overlay variants alter detail direction and tint strength so sequential rooms retain their own identity.
