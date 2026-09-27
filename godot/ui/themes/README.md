# BUGBOUND combat visual foundation — Phase 1

Assign `combat_theme.tres` to a UI root. It is a script-backed Godot Theme:
`combat_theme.gd` calls `bugbound_theme.gd.populate_theme()` in the editor and
at runtime. Edit tokens/factories in `bugbound_theme.gd`, then reload the resource
or restart the running scene. Do not maintain a second serialized palette.
StyleBoxes in the Theme are shared; duplicate before making a local mutation.

The existing UI root now loads this resource. Its previous Button, CompactAction,
PrimaryAction, PaperCard, LineEdit, tooltip and container defaults were moved
without changing their dimensions or colors. New semantic roles are opt-in for
later component work. This phase does not alter layout, cards, portraits,
backgrounds, combat rules, or existing HP color assignments.

## Token and style registry

All color constants and StyleBox construction live in `../bugbound_theme.gd`.
Colors are also exposed through `theme.get_color(token, "Bugbound")`.
Panel roles use `theme_type_variation`; their StyleBox item is `panel`.

| Requirement | Color constant / hex | Theme role or item |
|---|---|---|
| Background surface | INK / #070c19 | CombatBackground |
| Normal panel | SURFACE / #101a2c; LINE / #34516a | CombatPanel |
| Elevated panel | SURFACE_ELEVATED / #18263b | CombatElevated |
| Selected panel | SURFACE_SELECTED / #153342; CYAN | CombatSelected |
| Cyan border | CYAN / #50e5ee | CombatCyan |
| Magenta border | MAGENTA / #ff70bd | CombatMagenta |
| Warning/danger border | DANGER / #ff786f | CombatDanger |
| Normal button | SURFACE, LINE | Button / normal |
| Hover button | SURFACE_HOVER / #1d354b, CYAN | Button / hover |
| Pressed button | INK, LINE | Button / pressed |
| Disabled button | SURFACE_DISABLED / #111725, MUTED text | Button / disabled |
| HP | HP = DANGER | CombatHP / background, fill (ProgressBar) |
| Block | BLOCK = CYAN | CombatBlock / background, fill (ProgressBar) |
| Energy | ENERGY = ACID / #c4f76a | CombatEnergy / background, fill (ProgressBar) |
| Primary text | TEXT / #e5f5fa | CombatText |
| Secondary text | SECONDARY_TEXT = MUTED / #9fb5c9 | CombatHelp |
| Muted text | MUTED_TEXT / #7f95ab | CombatMuted |
| Attack accent | ATTACK = MAGENTA | Bugbound / attack color |
| Skill accent | SKILL = CYAN | Bugbound / skill color |
| System/status accent | STATUS = ACID | Bugbound / status color |

Button keyboard focus uses an acid-lime outline; PrimaryAction retains its
existing lime fill and pale focus outline. Border geometry, asymmetric corners,
padding and restrained shadow come from `panel_style()`. `decorate()` is the
shared, input-transparent circuit/packet detail; call it once on a frame.
It remains opt-in, since Themes cannot instantiate child controls.

## Typography and spacing

| Label role | Size | Token |
|---|---:|---|
| CombatScreenTitle | 27 | FONT_SCREEN_TITLE |
| CombatSectionTitle | 20 | FONT_SECTION_TITLE |
| CombatText | 18 | FONT_UI |
| CombatHelp / CombatMuted | 14 | FONT_HELP |
| CombatValue | 22 | FONT_STATUS |

Normal UI retains Godot's current font/fallback to preserve Chinese layout.
`terminal_font.tres` centralizes the existing Consolas → DejaVu Sans Mono →
monospace family for terminal tags and numeric values, with system glyph fallback.
Legacy CombatRule (16) and CombatSecondary (14) roles remain compatible.

Spacing constants, also available under the Theme's `Bugbound` type:
`GAP_SMALL / small_gap = 6`, `GAP / normal_gap = 12`,
`PANEL_PADDING / panel_padding = 12`, `SECTION_SPACING / section_spacing = 24`.
Existing component-specific margins remain unchanged.

Example for a future component:

```gdscript
frame.theme_type_variation = "CombatSelected"
heading.theme_type_variation = "CombatSectionTitle"
meter.theme_type_variation = "CombatHP"
row.add_theme_constant_override("separation", theme.get_constant("small_gap", "Bugbound"))
```

## Audit: controls that still bypass shared Theme roles

These are deliberately deferred rather than redesigned in Phase 1:

- `game_ui.gd`: `panel()` and `box()` use the shared StyleBox factory, but still
  install local overrides with caller-supplied fills, borders and padding.
  Arena transparency, enemy intent fill, preview/log entries, dialogs and the
  block badge therefore bypass the new named panel roles.
- Phase 2 replaces `health()` with `combat_status.gd` headers and the custom
  `status_meter.gd` integrity rail. These use shared palette, typography and
  StyleBox factories: cyan player HP, coral enemy HP, cyan shield capsules,
  and an acid-lime energy module. Energy shows base 3, explicitly not a cap.
- `label()`/`tag()` still apply explicit colors, font sizes and the shared
  terminal font; combat labels only partly use CombatRule/CombatSecondary.
  Status values, shortcut badges, pile buttons and monitor feedback have local
  typography/color overrides.
- Rows, screen margins, compact layouts, hand margins and component containers
  retain their local spacing. No replacement with new spacing tokens was made
  where it could alter geometry.
- `card_view.gd` overrides cost chips, art frames, text and locked-state tint.
  It uses the shared palette/factory and inherited PaperCard theme, but retains
  its own chip geometry and text sizing. `scenes/card.tscn` retains its margins,
  sizes and font-size overrides. Neither card file was edited.
- `game_ui.gd` still draws its backdrop dots/header line and uses local overlay
  colors. Noncombat menu/map/reward styling is also outside this phase.
- `game_feel.gd` uses shared palette constants for transient effects; these are
  custom drawing/modulation, not Theme-controlled widgets.

Future work should adopt these roles component by component, removing the
corresponding overrides as each component is reviewed. Do not globally replace
legacy `CORAL` (currently magenta): it also represents secondary/attack accents.
