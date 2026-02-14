# macmon

A lightweight macOS dock CPU monitor. No windows — just a live-updating graph in your dock icon.

![55KB binary, zero dependencies beyond macOS system frameworks.](https://img.shields.io/badge/binary-55KB-green)

## Features

- **Aggregate view** — rolling line graph of overall CPU usage (~1 minute history)
- **Per-core view** — vertical bars per core, color-coded green → yellow → red by load
- **Click** the dock icon to toggle between views
- **Right-click** for a menu with current CPU %, view toggle, and Exit

## Build

Requires Xcode Command Line Tools (`xcode-select --install`). No Xcode project needed.

```sh
make run
```

This compiles a single Objective-C file, bundles it into `macmon.app`, and launches it.

Other targets:

```sh
make        # build only
make clean  # remove build artifacts
```

## How it works

- CPU sampling via `host_processor_info()` (mach kernel API), polled at 1 Hz
- Dock icon rendered with CoreGraphics into a 256×256 bitmap (Retina), set via `NSApp.applicationIconImage`
- Single `main.m` file, ~270 lines of Objective-C/C
- ~0.1% CPU, ~55KB binary
