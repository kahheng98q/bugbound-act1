# BUGBOUND — Act 1 (Godot)

This folder is the native Godot 4.5 implementation of the Act 1 vertical slice. It is organized as:

- `core/seeded_rng.gd` — deterministic FNV-1a + Mulberry32 RNG compatible with the original run generator.
- `core/catalog.gd` — card, bug, enemy, and event data loaded from `data/catalog.json`.
- `core/map_generator.gd` — the 10-tier Desktop route and hidden node generation.
- `core/combat.gd` — battle state, card resolution, bug rewards/risks, bee mechanics, enemy intents, and popups.
- `core/run_state.gd` — run lifecycle and screen transitions.
- `ui/game_ui.gd` / `ui/card_view.gd` — native responsive Control UI and card presentation.
- `scenes/main.tscn` / `scenes/card.tscn` — reusable scene entry points.

The UI uses illustrated paper cards, a connected route map, health bars, a dedicated
bug monitor, and centered dialogs. The player-facing UI uses Chinese only; the former runtime language-switching path has been removed.
The hand scrolls horizontally when it contains more cards than fit in the window.

Combat shows incoming damage after current Block (including lethal warnings),
marks playable cards that trigger the active bug, and explains its reward/risk
on hover or keyboard focus. Swarm Loop shows its current damage; Nectar tooltips
explain spending it. The first battle includes guidance that can be dismissed
for the rest of the session. Route nodes show encounter traits and clarify
matching encounters. Installing or skipping a reward confirms the choice on the map.

The combat action bar groups current Energy, Nectar availability, and next-turn
Energy with its debt/cache breakdown. The header identifies route progress,
encounter type, and starting build. The bug monitor explains Trigger / Gain / Cost
and replacement on trigger. Hovering or focusing a card fills a reserved preview
area with known effects and bug consequences; unavailable cards remain focusable
to explain their requirements. Focusing Nectar opens its detailed help there.
Random draws and replacement bugs are never predicted or sampled by previews.

Focused keyboard, pointer, preview, and long-hand checks:

```powershell
.\run-godot.ps1 --headless --path godot --script res://tests/test_combat_clarity.gd
```

Combat rules resolve immediately; the previous arena remains visible until its
defeat and bug effects finish, then reward content appears without overlapping
combat effects. Navigation or rebuilding the screen cancels that presentation.

Read-only preview parity checks (including RNG preservation):

```powershell
.\run-godot.ps1 --headless --path godot --script res://tests/test_experience.gd
```

## GameFeel

`ui/game_feel.gd` is the reusable presentation service. The main scene exposes
`game_feel_settings`; edit `ui/default_game_feel.tres` in the Inspector to tune
hover, flight, damage, popup, flash, death, monitor, reward, and screen timings.
Hover defaults to 1.05 scale and a 12 px lift over 0.12 seconds, easing out.
Durations are in seconds; zero or negative timing values become 0.001 seconds.
Duplicate the settings resource to give another scene its own timing profile.

The service uses Tweens for movement and scale, and an AnimationPlayer timeline
for flashes. `ui/combat_feedback.gd` compares displayed and resolved battle state
at render time. It starts enemy damage/death, monitor completion, and screen shake
without changing `core/` or delaying actions. One action displays its net HP loss;
fully absorbed hits do not display a damage number. Monitor completion displays
the completed bug while its replacement is already active in the rules.

The bee uses `assets/bee-animation.png`, a transparent 4×4 sprite sheet: eight
idle frames with wing/eye/limb changes and eight attack frames. `ui/bee_portrait.gd`
plays idle at 5 FPS and attacks at 10 FPS, then returns to idle. The image
slot stays fixed. Animation phase survives battle UI rebuilds without consuming RNG.

```gdscript
var feel := GameFeel.new()
add_child(feel)

feel.card_hover(card_visual, true) # false reverses to the original pose
feel.card_play(feel.snapshot(card_visual), target_center, func():
    print("Visual impact"))
feel.enemy_damage(enemy_visual, 6)
feel.enemy_death(enemy_visual)
feel.monitor_complete(monitor_visual, progress_label, "BUG COMPLETE!",
    reward_icon, player_center)
feel.screen_shake(screen_control, 8.0, 0.22)
```

Targets use global canvas coordinates. Flights consume their disposable card or
reward visual. Enemy and monitor controls remain caller-owned; death leaves the
visual shrunk and transparent. Use a plain Control wrapper inside a Container
for animated controls (the card hand uses fixed layout slots). `snapshot()` makes
a visual copy with no scripts, signal connections, focus, or pointer handling.
Copies live in a separate CanvasLayer and survive ordinary UI rebuilds.

Impact/completion callbacks are for presentation only and run on normal completion;
cancelled effects never invoke them. `clear()` cancels effects, restores live
controls, and removes transient copies. The UI calls it when leaving the battle
flow. Screen shake accepts intensity and duration per call and uses its own
deterministic motion, consuming no gameplay randomness.

Focused checks cover animation cleanup, rapid hover/damage replacement, callbacks,
actual pointer/focus input, lethal transitions, and state/RNG parity with direct
combat actions. Add `-- --capture` and omit `--headless` to save effect screenshots:

```powershell
.\run-godot.bat --headless --path godot --script res://tests/test_game_feel.gd
```

## Validation and launching

UI interaction checks (menu, route selection, card click, pause, popup, rewards,
events, and Chinese card text bounds):

```powershell
.\run-godot.bat --headless --path godot --script res://tests/ui_smoke.gd
```

To also capture rendered screens in `work/`, omit `--headless` and append
`-- --capture`.

Combat-only visual validation uses the same capture workflow:

```powershell
.\run-godot.ps1 --path godot --script res://tests/ui_smoke.gd -- --capture --combat-only --states
```

It captures seed `BUG-404-LOL` at native 1280×720 and 1440×900 in Chinese
(`work/ui-combat-{width}-zh.png`). `--states` also checks
focus, hover, pressed, unaffordable cards, and every catalog card's compact
text bounds. Long card effects take space from their illustration before
text is clipped. Full UI smoke runs include these checks automatically.
For a restricted session, add `--log-file` with an absolute path under `work/`
before `--script` to keep the engine log inside the workspace.

Godot is not required to be on your PATH. From the repository root, use the included launcher (it uses the portable editor in `work/godot` when available):

```powershell
.\run-godot.ps1 --path godot
```

If PowerShell blocks local scripts, use the batch launcher instead:

```text
run-godot.bat --path godot
```

Alternatively, allow the script only for the current PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\run-godot.ps1 --path godot
```

You can also open `godot/project.godot` directly in Godot 4.5+. Run the validation suite headlessly from the repository root:

```text
.\run-godot.ps1 --headless --path godot --script res://tests/test_game.gd
```

The browser implementation lives in the separate sibling folder `../../bugbound-web`
(relative to this directory). The Godot project is self-contained: its data, assets,
and validation fixtures are stored here and do not import website files.

## Local AI tooling

Codex has a global MCP connection named `bugbound-godot`, installed from
[Vollkorn Games Godot MCP](https://github.com/Vollkorn-Games/godot-mcp) at commit
`632530638448ea3e79394fbf74e9a5c92c4b67e5`. Its source, dependencies, and build are
in the ignored `work/tools/godot-mcp` directory. It reuses the bundled Node.js
24.19.0 runtime, pnpm 11.19.0, and portable Godot 4.5 editor.

The connection uses absolute local paths. Restart Codex if the new tools do not
appear; moving this project or removing the bundled runtime requires updating
the connection. Image generation is already available through Codex.

Installation verification covered the MCP handshake, discovery of 75 tools,
Godot version, project inspection, a rendered Bugbound screenshot, and restoration
of `project.godot`. Evidence is in `work/godot-mcp-verification.log` and
`work/godot-mcp-verified.png`. This checks the connection, not every MCP operation.

To repeat the connection check from the repository root:

```powershell
node work/tools/verify-godot-mcp.mjs
```

Godot needs access to its normal user log directory and a graphical desktop for
rendered capture. In a restricted Codex session this can require an escalated run.
Use the existing UI smoke script for broader screen coverage. Run MCP capture and
interactive operations sequentially because they can temporarily inject helpers
into the project.
