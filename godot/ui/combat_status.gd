extends RefCounted
## Presentation-only header and resource modules, using the Phase 1 tokens.
const V = preload("res://ui/bugbound_theme.gd")
const METER = preload("res://ui/status_meter.gd")

static func text(parent: Node, copy: String, role: String, color: Color = V.TEXT) -> Label:
	var item := Label.new()
	item.text = copy
	item.theme_type_variation = role
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func frame(parent: Node, accent: Color, padding: int) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", V.panel_style(V.INK, accent.darkened(0.5), padding))
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	V.decorate(item, accent)
	return item

static func header(parent: Node, title: String, hp: int, maximum: int, block: int, enemy := false, strength := 0) -> PanelContainer:
	var accent: Color = V.MAGENTA if enemy else V.CYAN
	var shell := frame(parent, accent, 8)
	var header_style := shell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	header_style.content_margin_top = 3
	header_style.content_margin_bottom = 3
	shell.add_theme_stylebox_override("panel", header_style)
	shell.name = "EnemyCombatHeader" if enemy else "PlayerCombatHeader"
	shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	shell.add_child(body)
	var identity := HBoxContainer.new()
	body.add_child(identity)
	var heading := text(identity, title, "CombatSectionTitle")
	heading.name = "CombatName"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.tooltip_text = title
	var status := text(identity, "力量 +%d" % strength if enemy else "在线", "CombatHelp", V.DANGER if enemy and strength > 0 else V.MUTED)
	status.name = "EnemyStrength" if enemy else "PlayerSystemStatus"
	if not enemy: status.add_theme_color_override("font_color", V.ACID)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 6)
	body.add_child(values)
	text(values, "生命", "CombatHelp", V.MUTED)
	var hp_value := text(values, "%d / %d" % [hp, maximum], "CombatValue")
	hp_value.name = "HPValue"
	hp_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shield := PanelContainer.new()
	var style := V.panel_style(V.SURFACE_SELECTED if block > 0 else V.SURFACE, V.CYAN.darkened(0.35), 4)
	style.set_corner_radius_all(8)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	shield.add_theme_stylebox_override("panel", style)
	values.add_child(shield)
	var shield_row := HBoxContainer.new()
	shield_row.add_theme_constant_override("separation", 4)
	shield.add_child(shield_row)
	text(shield_row, "◇ 格挡", "CombatHelp", V.CYAN)
	var block_value := text(shield_row, str(block), "CombatValue", V.CYAN if block > 0 else V.MUTED)
	block_value.name = "BlockBadge"
	shield.tooltip_text = "格挡吸收伤害；敌人行动后重置。"
	var meter := METER.new()
	meter.name = "HPMeter"
	meter.value = hp
	meter.maximum = maximum
	meter.accent = V.DANGER if enemy else V.CYAN
	body.add_child(meter)
	return shell

static func energy(parent: Node, amount: int) -> PanelContainer:
	var shell := frame(parent, V.ENERGY, 6)
	shell.name = "EnergyModule"
	shell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shell.tooltip_text = "当前可用能量。基础每回合 3 点；额外效果可超过基础值。"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	shell.add_child(body)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	body.add_child(line)
	text(line, "能量", "CombatHelp", V.CYAN)
	var current := text(line, str(amount), "CombatValue", V.ENERGY)
	current.name = "EnergyValue"
	text(body, "基础 3 · 可超载", "CombatHelp", V.MUTED)
	return shell
