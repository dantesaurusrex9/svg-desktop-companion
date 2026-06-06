# DesktopCompanion Product Direction

This project is a native macOS desktop companion library. The product goal is to let users install SVG-based companion packages, manage them in a clean minimal library window, and spawn one or more desktop companion instances.

## Current Direction

- Opening the app should show the companion library UI first.
- The app should not create a default companion when no saved instances exist.
- Users should be able to spawn multiple companions from the same package.
- Spawned companions should persist package, position, layer, speech anchor, bubble placement, and animation preset.
- Users should be able to import a raw bounded SVG or an existing companion package folder.
- Future website downloads should map cleanly to companion package folders that can be installed into Application Support.

## Package Contract

Companion packages live under:

```text
~/Library/Application Support/<support-dir>/Companions/<package-id>/
```

Each package must contain `companion.json` and a bounded SVG using:

```text
viewBox="0 0 220 220"
```

The manifest owns package metadata, speech bubble anchor/placement, and animation preset. SVG `data-mouth-anchor` remains a fallback for older files.
Package IDs must use lowercase letters, numbers, and hyphens.

## Implementation Guardrails

- Keep the UI compact, dark, and utilitarian using the notes-dark palette: `#292929`, `#1f1f1f`, `#f8f8f2`, `#d2d3d3`, and amber accent `#fcba03`.
- Do not add a web service, marketplace backend, zip extraction, custom animation timeline engine, or broad plugin framework until explicitly requested.
- Keep import validation local and strict: bounded SVGs only, package paths must not escape their package folders, and imported packages must load through the same runtime loader as bundled packages.
