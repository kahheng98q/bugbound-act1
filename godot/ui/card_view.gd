extends Button

const BugboundTheme = preload("res://ui/bugbound_theme.gd")
const CardStyle = preload("res://ui/card_style.gd")
var _visual_state := ""
var _state_styles: Dictionary = {}
var _locked := false
var inspection_mode := false
var art_height := 104.0
var game_feel: Node
var hover_area: Control
var hover_allowed: Callable
var _hovered := false
var _hover_selected := false
var _hand_pose_offset_y := 0.0
var _hand_pose_rotation_degrees := 0.0
var _pointer := Vector2(-10000, -10000)


func set_hand_pose(offset_y: float, angle := 0.0) -> void:
	_hand_pose_offset_y = offset_y
	_hand_pose_rotation_degrees = clampf(angle, -3.0, 3.0)
	# The slot is still zero-sized while its Container assembles the hand.
	# Apply after layout so full-rect anchors do not retain stale right offsets.
	call_deferred("_apply_hand_pose")


func _apply_hand_pose() -> void:
	# The slot remains fixed for hit testing while callers fan the visible paper.
	# Resetting first prevents an in-flight hover tween from restoring an old pose.
	if is_instance_valid(game_feel): game_feel.reset_hover(self)
	# Reassert the full slot width, then move both vertical edges as one pose.
	offset_left = 0.0
	offset_right = 0.0
	offset_top = _hand_pose_offset_y
	offset_bottom = _hand_pose_offset_y
	# Fan only the paper around its lower centre; the parent slot remains the
	# pointer and focus target.
	pivot_offset = Vector2(size.x * 0.5, size.y)
	self.rotation_degrees = _hand_pose_rotation_degrees
	if _hovered and is_instance_valid(game_feel): game_feel.card_hover(self, true, _hover_selected)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer = get_canvas_transform().affine_inverse() * event.position

func _process(_delta: float) -> void:
	if not is_instance_valid(game_feel) or not is_instance_valid(hover_area): return
	# A fixed slot avoids hover flicker as the paper moves away from the pointer.
	var area := hover_area.get_global_rect()
	var ancestor := get_parent()
	while ancestor is Control:
		if ancestor.clip_contents: area = area.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	var allowed: bool = is_visible_in_tree() and (not hover_allowed.is_valid() or hover_allowed.call())
	var selected: bool = allowed and has_focus()
	var active: bool = selected or (allowed and area.has_point(_pointer))
	if active != _hovered or selected != _hover_selected:
		_hovered = active
		_hover_selected = selected
		game_feel.card_hover(self, active, selected)
		z_index = 12 if selected else (10 if active else 0)
	_update_frame(allowed)

func _update_frame(allowed := true) -> void:
	var state := "disabled" if _locked else ("normal" if inspection_mode else "playable")
	if allowed and has_focus(): state = "selected"
	elif allowed and _hovered: state = "hover"
	if allowed and is_pressed() and not _locked: state = "pressed"
	if state == _visual_state or _state_styles.is_empty(): return
	_visual_state = state
	# Fixed-slot hover and keyboard selection share one authoritative frame.
	for role in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(role, _state_styles[state])

func _exit_tree() -> void:
	if is_instance_valid(game_feel): game_feel.reset_hover(self)

func _ready() -> void:
	_pointer = get_global_mouse_position()
	get_viewport().mouse_exited.connect(func(): _pointer = Vector2(-10000, -10000))
	flat = false
	theme_type_variation = "PaperCard"
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	$Margin/Body/Top/Cost/Value.add_theme_color_override("font_color", BugboundTheme.INK)
	$Margin/Body/Top/Type.add_theme_color_override("font_color", BugboundTheme.CYAN)
	$Margin/Body/Name.add_theme_color_override("font_color", BugboundTheme.TEXT)
	$Margin/Body/Effect.add_theme_color_override("font_color", BugboundTheme.MUTED)
	$Margin/Body/LockNotice.add_theme_color_override("font_color", BugboundTheme.MAGENTA)
	resized.connect(func(): _fit_art.call_deferred())
	$Margin/Body.minimum_size_changed.connect(func(): _fit_art.call_deferred())
	_fit_art.call_deferred()

func _fit_art() -> void:
	# Preserve full rules text; long effects borrow space from the illustration.
	var art := $Margin/Body/ArtFrame
	var text_height: float = $Margin/Body.get_combined_minimum_size().y - art.custom_minimum_size.y
	var available := maxf(24, size.y - 18 - text_height)
	var target := minf(art_height, available)
	if absf(art.custom_minimum_size.y - target) > 0.5:
		art.custom_minimum_size.y = target

func configure(card: Dictionary, localize: Callable, action: Callable, locked: bool, inspect := false) -> void:
	inspection_mode = inspect
	locked = locked and not inspect
	_locked = locked
	disabled = locked
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	if not inspect and not pressed.is_connected(action): pressed.connect(action)
	tooltip_text = localize.call(Catalog.describe(card))
	var kind := str(card.get("kind", "skill"))
	var accent := CardStyle.accent_for(kind)
	var surface_accent := accent.lerp(BugboundTheme.MUTED, 0.8) if locked else accent
	for state in ["normal", "playable", "hover", "selected", "pressed", "disabled"]:
		var frame := CardStyle.frame(surface_accent, state)
		if state == "selected":
			frame.shadow_color = Color(surface_accent.lightened(0.25), 0.40)
			frame.shadow_size = 10
		_state_styles[state] = frame
	_visual_state = ""
	_update_frame()
	$Margin/Body/Top/Cost/Value.text = str(int(card.get("cost", 0)))
	$Margin/Body/Top/Type.text = localize.call(kind.to_upper())
	$Margin/Body/Top/Type.add_theme_color_override("font_color", surface_accent.lerp(BugboundTheme.MUTED, 0.35))
	$Margin/Body/Name.text = localize.call(str(card.get("name", "")))
	$Margin/Body/Effect.text = localize.call(Catalog.describe(card))
	$Margin/Body/Effect.add_theme_font_size_override("font_size", 16)
	$Margin/Body/Top/Type.add_theme_font_size_override("font_size", 14)
	$Margin/Body/LockNotice.add_theme_font_size_override("font_size", 14)
	$Margin/Body/LockNotice.visible = locked
	$Margin/Body/LockNotice.text = localize.call("REQUIREMENTS NOT MET")
	$Margin/Body/LockNotice.add_theme_color_override("font_color", BugboundTheme.MAGENTA)
	$Margin/Body/ArtFrame.add_theme_stylebox_override("panel", CardStyle.art_well(surface_accent))
	$Margin/Body/Top/Cost.add_theme_stylebox_override("panel", CardStyle.cost_chip(surface_accent))
	_set_art(card)
	_apply_locked_state()

func _set_art(card: Dictionary) -> void:
	var custom_art := {
		"web_trap": "res://assets/card-art/web-trap.svg",
		"inject": "res://assets/card-art/inject.svg",
		"breakpoint": "res://assets/card-art/breakpoint.svg",
		"stack_overflow": "res://assets/card-art/stack-overflow.svg",
		"release_candidate": "res://assets/card-art/release-candidate.svg",
	}
	var card_key := str(card.get("key", ""))
	if custom_art.has(card_key):
		$Margin/Body/ArtFrame/Art.texture = load(custom_art[card_key])
		var custom_material := ShaderMaterial.new()
		custom_material.shader = load("res://ui/paper_cutout.gdshader")
		$Margin/Body/ArtFrame/Art.material = custom_material
		return
	var index := -1
	for i in range(Catalog.data.cards.size()):
		if Catalog.data.cards[i].key == card.get("key", ""):
			index = i
			break
	if index < 0:
		$Margin/Body/ArtFrame/Art.texture = null
		return
	var bee := index >= 12
	if bee: index -= 12
	if card.has("artSlot"): index = card.artSlot
	var sheet: Texture2D = load("res://assets/variety-icons.png" if card.has("artSlot") else ("res://assets/bee-rewards.png" if bee else "res://assets/bugbound-icons.png"))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var cell := Vector2(sheet.get_width() / 4.0, sheet.get_height() / (2.0 if bee else 3.0))
	atlas.region = Rect2(Vector2(index % 4, int(index / 4.0)) * cell, cell)
	$Margin/Body/ArtFrame/Art.texture = atlas
	var paper_material := ShaderMaterial.new()
	paper_material.shader = load("res://ui/paper_cutout.gdshader")
	$Margin/Body/ArtFrame/Art.material = paper_material

func _apply_locked_state() -> void:
	var art_material = $Margin/Body/ArtFrame/Art.material
	if art_material is ShaderMaterial:
		art_material.set_shader_parameter("desaturation", 0.85 if _locked else 0.0)
	$Margin/Body/ArtFrame/Art.modulate = Color(0.54, 0.59, 0.58, 1.0) if _locked else Color.WHITE
	$Margin/Body/Name.add_theme_color_override("font_color", BugboundTheme.MUTED if _locked else BugboundTheme.TEXT)
	$Margin/Body/Effect.add_theme_color_override("font_color", BugboundTheme.MUTED if _locked else BugboundTheme.TEXT.darkened(0.12))
