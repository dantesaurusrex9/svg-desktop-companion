# DesktopCompanion

A small native macOS desktop companion: a transparent desktop-level SVG object that idles, reacts when typing is detected, and can be dragged around the desktop.

The default companion is a transparent 16-bit LEGO Vader-style SVG. When you type, it swings down and bashes the floor.

## Run

```sh
make run
```

## Build

```sh
make build
```

## Build an app bundle

```sh
make app
open .build/app/DesktopCompanion.app
```

## Controls

- Hover over the companion to reveal the quit button.
- Drag while hovering to move it.
- Right-click and choose `Test Bash` to preview the typing animation.
- Right-click and choose `Layer` to switch between `Desktop`, `Floating`, and `Always On Top`.
- Right-click and choose `Quit`.
- Press `Control + Option + Command + Q` to quit.

## Change the SVG

For runtime changes, install a bounded SVG as the user override:

```sh
make install-svg SVG=/path/to/companion.svg
```

The installer requires `viewBox="0 0 220 220"`. Then right-click the desktop companion and choose `Reload SVG`.

If you have a raster image, convert it into a simple bounded SVG mosaic override:

```sh
make install-image IMAGE=/path/to/image.png
```

Then right-click the desktop companion and choose `Reload SVG`.

The app loads SVGs in this order:

1. `~/Library/Application Support/DesktopCompanion/companion.svg`
2. bundled fallback: `Sources/DesktopCompanion/Resources/companion.svg`

For changing the bundled default, replace `Sources/DesktopCompanion/Resources/companion.svg`, then rebuild:

```sh
make app
open .build/app/DesktopCompanion.app
```

Keep the SVG inside `viewBox="0 0 220 220"` so it stays within the desktop object's bounds. The app ignores a manually placed runtime override that does not use those bounds. Custom SVGs without LEGO-specific hook classes still render and use the whole-object typing reaction; to keep the built-in floor-bash frames, preserve hook classes such as `lego-smash-arm`, `floor-crack`, and `impact-lines`.

## Typing Detection

The app asks for macOS Accessibility permission so it can notice global key events. Detected key presses queue a short hammer bash; rapid typing is coalesced so the companion keeps hitting without building a long catch-up backlog after you stop. It uses those events only to trigger animation. It does not read, display, store, or log typed content.

If Accessibility permission is denied, the companion still renders and drags, but it will not react to typing in other apps. A yellow warning icon appears on the companion while keyboard access is unavailable; click it to open the Accessibility settings pane. After permission is granted, the app retries the keyboard event tap automatically. macOS secure input fields may still block typing events.
