# DesktopCompanion

A small native macOS desktop companion library: import SVG companion packages, spawn one or more transparent desktop-level SVG objects, and drag them around the desktop.

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

To build a portable app bundle with a custom companion packaged inside it:

```sh
make companion-package SVG=/path/to/companion.svg ID=my-companion NAME="My Companion"
make app COMPANION_PACKAGE=.build/companions/my-companion APP_NAME=MyCompanion BUNDLE_ID=com.example.MyCompanion
open .build/app/MyCompanion.app
```

The resulting `.app` contains the selected companion package and can be copied to another Mac running macOS 13 or newer. `APP_NAME` and `BUNDLE_ID` are optional, but use a unique bundle ID if you want separate app permissions and preferences for different companion builds.

Custom app bundles use `APP_NAME` as their Application Support folder by default. Override `SUPPORT_DIR_NAME` if you want a different folder.

## Controls

- The app opens to a compact companion library window.
- Click `Spawn` to create a desktop companion from any available package.
- Click `Import SVG` to turn a bounded SVG into a package with speech anchor and animation metadata.
- Click `Import Package` to install an existing package folder.
- Hover over the companion to reveal the quit button.
- Drag while hovering to move it.
- Right-click and choose `Preview Animation` to preview the typing animation.
- Right-click and choose `Conversate` to ask a general question through the local Codex CLI.
- Right-click and choose `Bubble Theme` or `Reload Bubble Theme` to change the conversation bubble skin.
- Right-click and choose `Layer` to switch between `Desktop`, `Floating`, and `Always On Top`.
- Right-click and choose `Remove Companion`.
- Press `Control + Option + Command + Q` to quit.

## Conversate

The companion can open a speech bubble and send general questions to the local `codex` CLI. It runs `codex exec` in an isolated app-support folder with a read-only sandbox, so it is intended for casual answers rather than editing this repository.

The app looks for `codex` at `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and then the app process `PATH`.

The speech bubble is themeable. Bundled themes live in `Sources/DesktopCompanion/Resources/ConversationThemes`, and downloaded local themes can be placed under:

```sh
~/Library/Application Support/<support-dir>/ConversationThemes/<theme-id>/
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

## Import or Change the SVG

Use `Import SVG` in the library window for normal local changes. It validates `viewBox="0 0 220 220"` and stores the SVG as a package under Application Support.

For script-based runtime changes on the current Mac, install a bounded SVG as the legacy user override:

```sh
make install-svg SVG=/path/to/companion.svg
```

The installer requires `viewBox="0 0 220 220"`. Then right-click the desktop companion and choose `Reload SVG`.

For a renamed packaged app, target its support folder:

```sh
make install-svg SUPPORT_DIR_NAME=MyCompanion SVG=/path/to/companion.svg
```

If you have a raster image, convert it into a simple bounded SVG mosaic override:

```sh
make install-image IMAGE=/path/to/image.png
```

Then right-click the desktop companion and choose `Reload SVG`.

Spawned companions load SVGs in this order:

1. Spawned companion package from `~/Library/Application Support/<support-dir>/Companions/<package-id>/`
2. Bundled legacy fallback: `Sources/DesktopCompanion/Resources/companion.svg`
3. Generated fallback SVG

The legacy user override at `~/Library/Application Support/<support-dir>/companion.svg` is still available for script-based installs when no spawned package is being loaded.

For changing the bundled default, replace `Sources/DesktopCompanion/Resources/companion.svg`, then rebuild:

```sh
make app
open .build/app/DesktopCompanion.app
```

Keep the SVG inside `viewBox="0 0 220 220"` so it stays within the desktop object's bounds. The app ignores a manually placed runtime override that does not use those bounds. Custom SVGs without LEGO-specific hook classes still render and can use the whole-object typing reaction; to keep the built-in floor-bash frames, preserve hook classes such as `lego-smash-arm`, `floor-crack`, and `impact-lines`.

To align the conversation bubble tail for a custom companion SVG, set `speechAnchor` in `companion.json` in the same `0 0 220 220` coordinate space:

```json
"speechAnchor": { "x": 121, "y": 94 }
```

Older SVG metadata still works as a fallback:

```xml
<svg viewBox="0 0 220 220" data-mouth-anchor="121 94" ...>
```

You can also use `data-mouth-x="121"` and `data-mouth-y="94"`.

## Companion Packages

A companion package is a folder with a versioned manifest, the companion SVG, and optional package-local conversation themes:

```text
my-companion/
  companion.json
  companion.svg
  ConversationThemes/
    my-theme/
      theme.json
      bubble.svg
```

Minimal `companion.json`:

```json
{
  "schemaVersion": 1,
  "id": "my-companion",
  "displayName": "My Companion",
  "companionSVG": "companion.svg",
  "speechAnchor": { "x": 121, "y": 94 },
  "bubblePlacement": "automatic",
  "animationPreset": "wholeObjectReaction"
}
```

Package IDs must use lowercase letters, numbers, and hyphens. Add `"conversationThemesDirectory": "ConversationThemes"` when the package includes bubble themes. Install package folders under `~/Library/Application Support/<support-dir>/Companions/`, use `Import Package` in the library window, or pass one to `make app COMPANION_PACKAGE=/path/to/package` to embed it in the app bundle.

Supported `bubblePlacement` values are `automatic`, `above`, `right`, and `left`. Supported `animationPreset` values are `idleOnly`, `wholeObjectReaction`, and `legoSmash`.

## Typing Detection

The app asks for macOS Accessibility permission so it can notice global key events. Detected key presses queue a short hammer bash; rapid typing is coalesced so the companion keeps hitting without building a long catch-up backlog after you stop. It uses those events only to trigger animation. It does not read, display, store, or log typed content.

If Accessibility permission is denied, the companion still renders and drags, but it will not react to typing in other apps. A yellow warning icon appears on the companion while keyboard access is unavailable; click it to open the Accessibility settings pane. After permission is granted, the app retries the keyboard event tap automatically. macOS secure input fields may still block typing events.
