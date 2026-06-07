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
- Click `Spawn` to create an always-on-top desktop companion from any available package.
- Click `Import SVG` to turn a bounded SVG into a package with speech anchor and animation metadata.
- Click `Import Package` to install an existing package folder.
- Hover over the companion to reveal the quit button.
- Drag while hovering to move it.
- Use the library row preview buttons, or right-click and choose `Preview Animation`, to preview typing or thinking animations.
- Right-click and choose `Conversate` to ask a general question through the local Codex CLI.
- Drag or resize the transparent conversation text overlay to adjust its position and preferred size for that companion.
- Right-click and choose `Overlay Theme` or `Reload Overlay Theme` to change the conversation overlay metrics.
- Right-click and choose `Layer` to switch between `Desktop`, `Floating`, and `Always On Top`.
- Right-click and choose `Remove Companion`.
- Press `Control + Option + Command + Q` to quit.

## Conversate

The companion can open a transparent conversation overlay and send general questions to the local `codex` CLI. It streams the assistant response into the overlay as text arrives, expands the text area up to the safe visible screen bounds, and plays the thinking animation while the request is running. It runs `codex exec` in an isolated app-support folder with a read-only sandbox, so it is intended for casual answers rather than editing this repository.

The app looks for `codex` at `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and then the app process `PATH`.

The conversation overlay metrics are themeable. Bundled themes live in `Sources/DesktopCompanion/Resources/ConversationThemes`, and downloaded local themes can be placed under:

```sh
~/Library/Application Support/<support-dir>/ConversationThemes/<theme-id>/
```

Each theme folder contains a `theme.json` manifest and SVG assets, usually `bubble.svg` for compatibility. Use the right-click `Overlay Theme` submenu to select a theme, or `Reload Overlay Theme` after changing files. The transparent overlay uses the manifest width, content insets, input height, spacing, and anchor metrics; `tailFillColor` and `tailStrokeColor` are retained for older themes.

Minimal `theme.json`:

```json
{
  "schemaVersion": 1,
  "id": "my-cloud",
  "displayName": "My Cloud",
  "bubbleSVG": "bubble.svg",
  "width": 520,
  "minHeight": 300,
  "maxVisibleHeightRatio": 0.5,
  "contentInsets": { "top": 42, "left": 42, "bottom": 30, "right": 42 },
  "inputHeight": 42,
  "transcriptInputSpacing": 16,
  "tailAnchor": { "x": 94, "y": 0 },
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

To align the transparent conversation overlay for a custom companion SVG, set `speechAnchor` in `companion.json` in the same `0 0 220 220` coordinate space:

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

Package IDs must use lowercase letters, numbers, and hyphens. Add `"conversationThemesDirectory": "ConversationThemes"` when the package includes conversation overlay themes. Install package folders under `~/Library/Application Support/<support-dir>/Companions/`, use `Import Package` in the library window, or pass one to `make app COMPANION_PACKAGE=/path/to/package` to embed it in the app bundle.

Supported `bubblePlacement` values are `automatic`, `above`, `right`, and `left`. Supported `animationPreset` values are `idleOnly`, `wholeObjectReaction`, and `legoSmash`. Each active preset supports shared animation states for typing and thinking; `idleOnly` disables both.

## Typing Detection

The app asks for macOS Accessibility permission so it can notice global key events. Detected key presses queue a short hammer bash; rapid typing is coalesced so the companion keeps hitting without building a long catch-up backlog after you stop. It uses those events only to trigger animation. It does not read, display, store, or log typed content.

If Accessibility permission is denied, the companion still renders and drags, but it will not react to typing in other apps. A yellow warning icon appears on the companion while keyboard access is unavailable; click it to open the Accessibility settings pane. After permission is granted, the app retries the keyboard event tap automatically. macOS secure input fields may still block typing events.
