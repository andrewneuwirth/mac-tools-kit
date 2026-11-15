<div align="center">

<img src="docs/images/icon.png" width="128" height="128" alt="Kit icon">

# Kit (MacToolsKit)

**The shared Swift code behind the newi tools Mac apps.**

[![CI](https://github.com/andrewneuwirth/mac-tools-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewneuwirth/mac-tools-kit/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6.2%20tools-F05138.svg)](Package.swift)
[![Platform](https://img.shields.io/badge/platform-macOS%2026-lightgrey.svg)](Package.swift)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-library-orange.svg)](Package.swift)

</div>

What's in it:

- the design-system tokens in Swift: colours, spacing, radii, motion, status, partner colours
- the usage reading Pier writes
- the project list Pier and Projects share
- the Open at Login toggle
- the icon plate generators (`tools/icon.swift`, `tools/icon-tile.swift`)

The tokens mirror the newi tools design system; change a value there and here together.

```mermaid
flowchart LR
    DS["newi tools design system<br/>tokens.json"] -. mirrored by hand .-> Kit["MacToolsKit<br/>Tokens · Shared · ProjectIcon"]
    Kit --> A1["Pier"]
    Kit --> A2["Projects"]
    Kit --> A3["other Mac apps"]
    Local["../Kit checkout"] -->|used when present| Kit
    Remote["this repo via SwiftPM"] -->|otherwise| Kit
```

## Use it

The apps use a checkout next to them named `Kit` when there is one, otherwise SwiftPM fetches this repo. To work on
Kit and an app together, clone it next to the app:

```sh
git clone https://github.com/andrewneuwirth/mac-tools-kit.git Kit
```

`swift test` runs its checks.

## Tokens at a glance

Values from [`Sources/MacToolsKit/Tokens.swift`](Sources/MacToolsKit/Tokens.swift).

| Spacing (`MT.Space`) | Radius (`MT.Radius`) | Motion (`MT.Motion`) |
|---|---|---|
| 4 · 6 · 8 · 10 · 12 · 18 · 26 | control 8 · row 10 · card 14 · panel 18 · section 24 | quick 0.15 s ease · panel spring 0.3 s · value smooth 0.45 s (off under Reduce Motion) |

| Status | Light | Dark | | App accent | Colour |
|---|---|---|---|---|---|
| `mtGood` | ![#2f9e5b](https://img.shields.io/badge/%20-%20-2f9e5b?style=flat-square) `#2f9e5b` | ![#66cc87](https://img.shields.io/badge/%20-%20-66cc87?style=flat-square) `#66cc87` | | `mtJot` | ![#338cfa](https://img.shields.io/badge/%20-%20-338cfa?style=flat-square) `#338cfa` |
| `mtWarn` | ![#b7791f](https://img.shields.io/badge/%20-%20-b7791f?style=flat-square) `#b7791f` | ![#f2b545](https://img.shields.io/badge/%20-%20-f2b545?style=flat-square) `#f2b545` | | `mtProjects` | ![#807ef2](https://img.shields.io/badge/%20-%20-807ef2?style=flat-square) `#807ef2` |
| `mtBad` | ![#d64541](https://img.shields.io/badge/%20-%20-d64541?style=flat-square) `#d64541` | ![#e85754](https://img.shields.io/badge/%20-%20-e85754?style=flat-square) `#e85754` | | `mtHangar` | ![#ed8f5c](https://img.shields.io/badge/%20-%20-ed8f5c?style=flat-square) `#ed8f5c` |
| | | | | `mtLinkChoice` | ![#fa5c5c](https://img.shields.io/badge/%20-%20-fa5c5c?style=flat-square) `#fa5c5c` |
| **Partner** | | | | `mtCommandCenter` | ![#1fb6c9](https://img.shields.io/badge/%20-%20-1fb6c9?style=flat-square) `#1fb6c9` |
| `mtClaude` | ![#d97757](https://img.shields.io/badge/%20-%20-d97757?style=flat-square) `#d97757` | | | `mtVitals` | ![#8bc34a](https://img.shields.io/badge/%20-%20-8bc34a?style=flat-square) `#8bc34a` |
| `mtChatGPT` | ![#10a37f](https://img.shields.io/badge/%20-%20-10a37f?style=flat-square) `#10a37f` | | | `mtUsageRings` | ![#b98fdd](https://img.shields.io/badge/%20-%20-b98fdd?style=flat-square) `#b98fdd` |

Usage status thresholds (`MTStatus.forUsage`): **50%** warns, **80%** is bad.

## Icon plates

`tools/icon-tile.swift` draws one colour and one SF Symbol on Apple's icon grid (an 824 tile inset 100 on the 1024
canvas, radius 185) and writes an `.icns` or `.png`. `tools/icon.swift` draws the family plate, with the accent
sunk into the dark ground.

```sh
swift tools/icon-tile.swift 338cfa square.grid.2x2.fill icon.png
swift tools/icon.swift <accent hex> <SF Symbol name | glyph.svg> <out.icns>
```

<p>
  <img src="docs/images/tile-kit.png" width="96" alt="Tile: square grid">
  <img src="docs/images/tile-pptx.png" width="96" alt="Tile: stacked rectangles">
  <img src="docs/images/tile-sheets.png" width="96" alt="Tile: table cells">
  <img src="docs/images/tile-html.png" width="96" alt="Tile: bar chart">
  <img src="docs/images/tile-tone.png" width="96" alt="Tile: guitars">
</p>

<sub>Output of `tools/icon-tile.swift` with five colours and symbols.</sub>

## BuildJanitor

[`tools/BuildJanitor`](tools/BuildJanitor/README.md) holds BuildJanitor, the Claude Code hook and nightly janitor that
keep agent Xcode builds and simulators from filling the disk (Python, see its README). Point its hooks at your
checkout's `tools/BuildJanitor` (or a symlink to it).

| 2,000+ | 67 GB | 3 |
|:---:|:---:|:---:|
| full clean builds in 30 days, none deleted, before BuildJanitor | of simulator copies piled up in CoreSimulator/Devices | shared, reused DerivedData slots per project after |

## License

[MIT](LICENSE). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Security: [SECURITY.md](SECURITY.md).
