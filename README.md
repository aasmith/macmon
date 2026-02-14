# macmon

A lightweight macOS dock CPU monitor. No windows — just a live-updating graph in your dock icon.

![55KB binary, zero dependencies beyond macOS system frameworks.](https://img.shields.io/badge/binary-55KB-green)

## Features

- **Aggregate view** — rolling line graph of overall CPU usage (~1 minute history)
- **Per-core bars** — vertical bars per core, color-coded green → yellow → red by load
- **Per-core graphs** — tiled mini line graphs, one per core, with rolling history
- **P/E core distinction** — efficiency cores marked with blue tint (Apple Silicon)
- **Configurable polling** — 1s, 2s, 5s, or 10s update interval via dock menu
- **Click** the dock icon to cycle between views
- **Right-click** for a menu with CPU info, view selection, interval, and Quit

## Build

Requires Xcode Command Line Tools (`xcode-select --install`). No Xcode project needed.

```sh
make run
```

This compiles, ad-hoc codesigns, and launches `macmon.app`.

## Distribution

To create a DMG with a drag-to-Applications installer:

```sh
make dist
```

This produces `macmon.dmg`. Recipients on Apple Silicon may need to right-click → Open on first launch (ad-hoc signed, not notarized).

## Other targets

```sh
make        # build + sign
make run    # build + launch
make dist   # build + create DMG
make clean  # remove all build artifacts
```

## How it works

- CPU sampling via `host_processor_info()` (mach kernel API)
- Core topology via `sysctlbyname()` (P-core/E-core detection)
- Dock icon rendered with CoreGraphics into a 256×256 bitmap (Retina)
- Single `main.m` file, ~540 lines of Objective-C/C
- Follows Apple energy efficiency guidelines: timer coalescing tolerance, reused graphics contexts, cached mach ports, App Nap prevention via `NSProcessInfo` activity assertion
- ~0.6% CPU, ~55KB binary, 30KB DMG
