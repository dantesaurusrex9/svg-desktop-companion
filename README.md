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
- Right-click and choose `Conversate` to ask a general question through the local Codex CLI.
- Right-click and choose `Bubble Theme` or `Reload Bubble Theme` to change the conversation bubble skin.
- Right-click and choose `Layer` to switch between `Desktop`, `Floating`, and `Always On Top`.
- Right-click and choose `Quit`.
- Press `Control + Option + Command + Q` to quit.

## Conversate

The companion can open a speech bubble and send general questions to the local `codex` CLI. It runs `codex exec` in an isolated app-support folder with a read-only sandbox, so it is intended for casual answers rather than editing this repository.

The app looks for `codex` at `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and then the app process `PATH`.

The speech bubble is themeable. Bundled themes live in `Sources/DesktopCompanion/Resources/ConversationThemes`, and downloaded local themes can be placed under:

```sh
~/Library/Application Support/DesktopCompanion/ConversationThemes/<theme-id>/
```

Each bubble theme folder contains a `theme.json` manifest and SVG assets, usually `bubble.svg`. Use the right-click `Bubble Theme` submenu to select a theme, or `Reload Bubble Theme` after changing files. `tailAnchor` is the connector attachment point on the bubble body, measured from the bubble body's lower-left corner. `tailFillColor` and `tailStrokeColor` are optional `#RRGGBB` or `#RRGGBBAA` colors for the connector.

Minimal `theme.json`:

```json
{
  "schemaVersion": 1,
  "id": "my-cloud",
  "displayName": "My Cloud",
  "bubbleSVG": "bubble.svg",
  "width": 360,
  "minHeight": 190,
  "maxVisibleHeightRatio": 0.5,
  "contentInsets": { "top": 34, "left": 36, "bottom": 26, "right": 36 },
  "inputHeight": 34,
  "transcriptInputSpacing": 12,
  "tailAnchor": { "x": 72, "y": 0 },
  "tailFillColor": "#FFFFFFF5",
  "tailStrokeColor": "#0000001F"
}
```

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

To align the conversation bubble tail for a custom companion SVG, add a mouth anchor to the SVG root in the same `0 0 220 220` coordinate space:

```xml
<svg viewBox="0 0 220 220" data-mouth-anchor="121 94" ...>
```

You can also use `data-mouth-x="121"` and `data-mouth-y="94"`.

## Typing Detection

The app asks for macOS Accessibility permission so it can notice global key events. Detected key presses queue a short hammer bash; rapid typing is coalesced so the companion keeps hitting without building a long catch-up backlog after you stop. It uses those events only to trigger animation. It does not read, display, store, or log typed content.

If Accessibility permission is denied, the companion still renders and drags, but it will not react to typing in other apps. A yellow warning icon appears on the companion while keyboard access is unavailable; click it to open the Accessibility settings pane. After permission is granted, the app retries the keyboard event tap automatically. macOS secure input fields may still block typing events.
