# BUGBOUND — Godot game

This project contains the native Godot game. The website is a separate sibling
folder at `../bugbound-web`.

## Play

Open `godot/project.godot` in Godot and press **F5**, or run from this folder:

```powershell
.\run-godot.bat --path godot
```

The launcher uses the portable editor in `work/godot` when available, otherwise
it looks for `godot` on PATH.

## Structure

- `godot/` — game scenes, UI, gameplay code, assets, and tests.
- `run-godot.bat` / `run-godot.ps1` — local launchers.
- `work/` — ignored local editor, logs, screenshots, and migration utilities.

See [the game README](godot/README.md) for validation commands.

## Website

The website's `app/`, `public/`, `tests/`, JavaScript packages, configuration,
and hosting metadata have moved together to `../bugbound-web`. Run website
commands from that folder. Godot does not require the website or Node.js.

The existing Git history remains in this repository; the sibling website folder
does not yet have a separate Git repository. The move is uncommitted, so Git
shows the original website files as removed from this checkout.
