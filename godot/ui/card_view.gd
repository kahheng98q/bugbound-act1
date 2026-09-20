extends Button

const INK := Color("15272c")
const CORAL := Color("dd725e")
const TEAL := Color("60b69b")
const AMBER := Color("e7b94c")
var _locked := false
var art_height := 104.0
var game_feel: Node
var hover_area: Control
var hover_allowed: Callable
var _hovered := false
var _pointer := Vector2(-10000, -10000)

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
	var allowed: bool = not disabled and is_visible_in_tree() and (not hover_allowed.is_valid() or hover_allowed.call())
	var active: bool = allowed and (has_focus() or area.has_point(_pointer))
	if active != _hovered:
		_hovered = active
		game_feel.card_hover(self, active)

func _exit_tree() -> void:
	if is_instance_valid(game_feel): game_feel.reset_hover(self)

func _ready() -> void:
	_pointer = get_global_mouse_position()
	get_viewport().mouse_exited.connect(func(): _pointer = Vector2(-10000, -10000))
	flat = false
	theme_type_variation = "PaperCard"
	resized.connect(func(): _fit_art.call_deferred())
	$Margin/Body.minimum_size_changed.connect(func(): _fit_art.call_deferred())
	_fit_art.call_deferred()

func _fit_art() -> void:
	# Preserve full rules text; long effects borrow space from the illustration.
	var art := $Margin/Body/ArtFrame
	var text_height: float = $Margin/Body.get_combined_minimum_size().y - art.custom_minimum_size.y
	var available := maxf(32, size.y - 18 - text_height)
	var target := minf(art_height, available)
	if absf(art.custom_minimum_size.y - target) > 0.5:
		art.custom_minimum_size.y = target

func configure(card: Dictionary, localize: Callable, action: Callable, locked: bool) -> void:
	_locked = locked
	disabled = locked
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(action): pressed.connect(action)
	tooltip_text = localize.call(Catalog.describe(card))
	var kind := str(card.get("kind", "skill"))
	var accent := AMBER if card.get("key", "") in Catalog.BEE else _accent_for(kind)
	$Margin/Body/Top/Cost/Value.text = str(int(card.get("cost", 0)))
	$Margin/Body/Top/Type.text = localize.call(kind.to_upper())
	$Margin/Body/Top/Type.add_theme_color_override("font_color", accent.darkened(0.52))
	$Margin/Body/Name.text = localize.call(str(card.get("name", "")))
	$Margin/Body/Effect.text = localize.call(Catalog.describe(card))
	$Margin/Body/LockNotice.visible = locked
	$Margin/Body/LockNotice.text = localize.call("REQUIREMENTS NOT MET")
	$Margin/Body/ArtFrame.add_theme_stylebox_override("panel", _frame_style(accent))
	$Margin/Body/Top/Cost.add_theme_stylebox_override("panel", _cost_style(accent))
	_set_art(card)
	_apply_locked_state()

func _set_art(card: Dictionary) -> void:
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
	var sheet: Texture2D = load("res://assets/bee-rewards.png" if bee else "res://assets/bugbound-icons.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var cell := Vector2(sheet.get_width() / 4.0, sheet.get_height() / (2.0 if bee else 3.0))
	atlas.region = Rect2(Vector2(index % 4, int(index / 4.0)) * cell, cell)
	$Margin/Body/ArtFrame/Art.texture = atlas
	var paper_material := ShaderMaterial.new()
	paper_material.shader = load("res://ui/paper_cutout.gdshader")
	$Margin/Body/ArtFrame/Art.material = paper_material

func _frame_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e4dfca")
	style.border_color = accent.darkened(0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _cost_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(12)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _accent_for(kind: String) -> Color:
	return CORAL if kind == "attack" else (AMBER if kind == "bee" else TEAL)

func _apply_locked_state() -> void:
	$Margin/Body/ArtFrame/Art.modulate = Color(0.54, 0.59, 0.58, 1.0) if _locked else Color.WHITE
	$Margin/Body/Name.modulate = Color.WHITE
	$Margin/Body/Effect.modulate = Color.WHITE
