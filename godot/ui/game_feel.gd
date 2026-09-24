class_name GameFeel
extends Node
## A presentation-only effect layer. Callers retain ownership of live gameplay nodes.

const DEFAULT_SETTINGS = preload("res://ui/default_game_feel.tres")
const EPSILON := 0.001

@export var settings: GameFeelSettings = DEFAULT_SETTINGS

var effects_layer: CanvasLayer
var effects_root: Control
var _tweens: Array[Tween] = []
var _hover: Dictionary = {}
var _restores: Dictionary = {}
var _shakes: Dictionary = {}
var _actor_effects: Dictionary = {}
var _flash_targets: Dictionary = {}
var _shake_serial := 0


func _ready() -> void:
	_ensure_layer()


func _exit_tree() -> void:
	clear()


func snapshot(source: Control) -> Control:
	_ensure_layer()
	if not is_instance_valid(source): return null
	var copy := source.duplicate(0)
	_strip_interaction(copy)
	copy.theme = _effective_theme(source)
	copy.visible = true
	var snapshot_size := source.size
	copy.minimum_size_changed.connect(func(): copy.set_deferred("size", snapshot_size))
	# Keep the source dimensions throughout duplication: briefly collapsing a
	# Container makes wrapped labels inflate its minimum height permanently.
	copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	effects_root.add_child(copy)
	copy.size = source.size
	copy.scale = source.get_global_transform().get_scale()
	copy.rotation = source.get_global_transform().get_rotation()
	copy.global_position = source.global_position
	copy.set_deferred("size", snapshot_size)
	return copy


func card_hover(view: Control, active: bool) -> Tween:
	if not is_instance_valid(view): return null
	var key := view.get_instance_id()
	if not _hover.has(key):
		_hover[key] = {"ref": weakref(view), "position": view.position, "scale": view.scale, "pivot": view.pivot_offset}
		_center_pivot(view)
	_kill_hover(key)
	var rest: Dictionary = _hover[key]
	var tween := _track(create_tween().bind_node(view))
	var duration := _duration(settings.hover_duration)
	if active:
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(view, "scale", rest.scale * settings.hover_scale, duration)
		tween.parallel().tween_property(view, "position", rest.position - Vector2(0, settings.hover_lift), duration)
	else:
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(view, "scale", rest.scale, duration)
		tween.parallel().tween_property(view, "position", rest.position, duration)
		tween.finished.connect(func(): _finish_hover(key))
	_hover[key].tween = tween
	return tween


func reset_hover(view: Control) -> void:
	if not is_instance_valid(view): return
	var key := view.get_instance_id()
	if not _hover.has(key): return
	_kill_hover(key)
	var rest: Dictionary = _hover[key]
	view.position = rest.position
	view.scale = rest.scale
	view.pivot_offset = rest.pivot
	_hover.erase(key)


func card_play(card: Control, target_position: Vector2, on_impact: Callable = Callable()) -> Tween:
	if not is_instance_valid(card): return null
	_center_pivot(card)
	var origin_position := card.position
	var origin_scale := card.scale
	var origin_rotation := card.rotation
	var tween := _track(create_tween().bind_node(card))
	var anticipation := _duration(settings.anticipation_duration)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "position", origin_position - Vector2(0, settings.anticipation_lift), anticipation)
	tween.parallel().tween_property(card, "scale", origin_scale * settings.anticipation_scale, anticipation)
	tween.parallel().tween_property(card, "rotation", origin_rotation - settings.play_rotation * 0.35, anticipation)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card, "position", _center_target(card, target_position), _duration(settings.play_duration))
	tween.parallel().tween_property(card, "rotation", origin_rotation + settings.play_rotation, _duration(settings.play_duration))
	tween.parallel().tween_property(card, "scale", origin_scale * 0.86, _duration(settings.play_duration))
	tween.tween_callback(func():
		if not is_instance_valid(card): return
		_impact_burst(target_position, Color("67e8f9"))
		if on_impact.is_valid(): on_impact.call()
		card.queue_free())
	return tween


func enemy_attack(attacker: Control, target_position: Vector2, damage_amount: int, screen_target: Control = null, hit_target: Control = null) -> Tween:
	if not is_instance_valid(attacker): return null
	_ensure_layer()
	_center_pivot(attacker)
	var origin_position := attacker.position
	var origin_scale := attacker.scale
	var origin_rotation := attacker.rotation
	var attacker_center := attacker.get_global_rect().get_center()
	var direction := (target_position - attacker_center).normalized()
	if direction.is_zero_approx(): direction = Vector2.LEFT
	var windup_position := origin_position - direction * settings.enemy_attack_windup_distance
	var impact_center := target_position - direction * settings.enemy_attack_stop_distance
	var tween := _track(create_tween().bind_node(attacker))
	_flash(attacker, Color(1.55, 0.72, 0.72, 1.0), settings.enemy_attack_flash_duration)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(attacker, "position", windup_position, _duration(settings.enemy_attack_windup_duration))
	tween.parallel().tween_property(attacker, "scale", origin_scale * settings.enemy_attack_scale, _duration(settings.enemy_attack_windup_duration))
	tween.parallel().tween_property(attacker, "rotation", origin_rotation - direction.y * 0.08, _duration(settings.enemy_attack_windup_duration))
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", _center_target(attacker, impact_center), _duration(settings.enemy_attack_launch_duration))
	tween.parallel().tween_property(attacker, "scale", origin_scale * 0.94, _duration(settings.enemy_attack_launch_duration))
	tween.tween_callback(func():
		_impact_burst(target_position, Color("ff5c6c"))
		_system_flash(Color("ff5c6c"), settings.enemy_attack_flash_duration)
		if is_instance_valid(screen_target):
			screen_shake(screen_target, settings.enemy_attack_shake_intensity, settings.shake_duration)
		if is_instance_valid(hit_target):
			_flash(hit_target, Color(1.45, 0.72, 0.72, 1.0), settings.enemy_attack_flash_duration)
		var message := "-%d" % damage_amount if damage_amount > 0 else "BLOCKED"
		var popup := _text_popup(message, target_position - Vector2(28, 42))
		popup.add_theme_font_size_override("font_size", 28)
		popup.add_theme_color_override("font_color", Color("ff8b94") if damage_amount > 0 else Color("75cbb0"))
		_popup_motion(popup, settings.damage_popup_duration))
	tween.tween_interval(_duration(settings.enemy_attack_flash_duration) * 0.45)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(attacker, "position", origin_position, _duration(settings.enemy_attack_recover_duration))
	tween.parallel().tween_property(attacker, "scale", origin_scale, _duration(settings.enemy_attack_recover_duration))
	tween.parallel().tween_property(attacker, "rotation", origin_rotation, _duration(settings.enemy_attack_recover_duration))
	tween.tween_property(attacker, "modulate:a", 0.0, _duration(settings.enemy_attack_recover_duration) * 0.45)
	tween.tween_callback(func():
		if is_instance_valid(attacker): attacker.queue_free())
	return tween


func enemy_damage(actor: Control, amount: int, on_finished: Callable = Callable()) -> Tween:
	if not is_instance_valid(actor): return null
	_replace_actor_effect(actor)
	var state := _remember(actor)
	var impact_point := actor.get_global_rect().get_center()
	var popup := _damage_popup(amount, actor.global_position + Vector2(actor.size.x * 0.5, 0))
	_flash(actor, Color(1.55, 1.30, 0.88, 1.0), settings.flash_duration)
	_impact_burst(impact_point, Color("ffd166"))
	var tween := _track(create_tween().bind_node(actor))
	_actor_effects[actor.get_instance_id()] = tween
	var duration := _duration(settings.damage_duration)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(actor, "position:x", state.position.x - settings.damage_knockback, duration * 0.22)
	tween.tween_property(actor, "position:x", state.position.x + settings.damage_knockback * 0.55, duration * 0.28)
	tween.tween_property(actor, "position", state.position, duration * 0.50)
	_popup_motion(popup, settings.damage_popup_duration)
	if settings.flash_duration > duration: tween.tween_interval(settings.flash_duration - duration)
	tween.tween_callback(func():
		_restore(actor)
		if is_instance_valid(actor): _actor_effects.erase(actor.get_instance_id())
		if on_finished.is_valid(): on_finished.call())
	return tween


func enemy_death(actor: Control, on_finished: Callable = Callable()) -> Tween:
	if not is_instance_valid(actor): return null
	_replace_actor_effect(actor)
	var state := _remember(actor)
	_center_pivot(actor)
	var tween := _track(create_tween().bind_node(actor))
	_actor_effects[actor.get_instance_id()] = tween
	var duration := _duration(settings.death_duration)
	_impact_burst(actor.get_global_rect().get_center(), Color("ff6b6b"))
	tween.tween_property(actor, "position:x", state.position.x - 7.0, duration * 0.12)
	tween.tween_property(actor, "position:x", state.position.x + 7.0, duration * 0.12)
	tween.tween_property(actor, "position", state.position, duration * 0.12)
	tween.parallel().tween_property(actor, "scale", Vector2(state.scale.x * settings.death_squash, state.scale.y / settings.death_squash), duration * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "scale", state.scale * 0.05, duration * 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(actor, "modulate:a", 0.0, duration * 0.64)
	tween.tween_callback(func():
		if is_instance_valid(actor):
			_restores.erase(actor.get_instance_id())
			_actor_effects.erase(actor.get_instance_id())
		if on_finished.is_valid(): on_finished.call())
	return tween


func monitor_complete(monitor: Control, progress: Control, completion_text: String, reward_icon: Control, target_position: Vector2) -> Tween:
	_ensure_layer()
	var tween := _track(create_tween())
	var duration := _duration(settings.monitor_duration)
	if is_instance_valid(monitor):
		screen_shake(monitor, 5.0, duration)
	if is_instance_valid(progress):
		_flash(progress, Color(1.50, 1.26, 0.70, 1.0), settings.monitor_flash_duration)
	var alert_center := monitor.get_global_rect().get_center() if is_instance_valid(monitor) else target_position
	_impact_burst(alert_center, Color("67e8f9"))
	_system_flash(Color("67e8f9"), settings.monitor_flash_duration)
	_scanline(Color("67e8f9"))
	var pop := _text_popup(completion_text, monitor.global_position + Vector2(10, 4) if is_instance_valid(monitor) else target_position)
	_center_pivot(pop)
	pop.scale = Vector2.ONE * 0.7
	var text_duration := _duration(settings.completion_text_duration)
	var text_tween := _track(create_tween().bind_node(pop))
	text_tween.tween_property(pop, "scale", Vector2.ONE, text_duration * 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	text_tween.tween_interval(text_duration * 0.15)
	text_tween.tween_property(pop, "position:y", pop.position.y - 24.0, text_duration * 0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	text_tween.parallel().tween_property(pop, "modulate:a", 0.0, text_duration * 0.60).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(maxf(text_duration, maxf(duration, _duration(settings.flash_duration))))
	if is_instance_valid(reward_icon):
		var reward_position := reward_icon.global_position
		if reward_icon.get_parent() != effects_root:
			if reward_icon.get_parent(): reward_icon.reparent(effects_root, true)
			else: effects_root.add_child(reward_icon)
		reward_icon.global_position = reward_position
		_center_pivot(reward_icon)
		tween.parallel().tween_property(reward_icon, "position", _center_target(reward_icon, target_position), _duration(settings.reward_fly_duration)).set_delay(duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(reward_icon, "scale", reward_icon.scale * 0.55, _duration(settings.reward_fly_duration)).set_delay(duration * 0.25)
	tween.tween_callback(func():
		if is_instance_valid(pop): pop.queue_free()
		if is_instance_valid(reward_icon): reward_icon.queue_free()
		_remove_flashes(progress))
	return tween


func show_system_alert(message: String, color_type := "cyan", shake_target: Control = null) -> Tween:
	_ensure_layer()
	var color := Color("67e8f9")
	match color_type.to_lower():
		"red": color = Color("ff5c6c")
		"purple": color = Color("c084fc")
	_system_flash(color, settings.alert_flash_duration)
	_scanline(color)
	var label := _text_popup(message, effects_root.size * 0.5)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color)
	_center_pivot(label)
	label.position -= label.size * 0.5
	label.scale = Vector2.ONE * 0.72
	if is_instance_valid(shake_target):
		screen_shake(shake_target, settings.alert_shake_intensity, settings.alert_flash_duration + settings.scanline_duration)
	var tween := _track(create_tween().bind_node(label))
	var duration := _duration(settings.alert_duration)
	tween.tween_property(label, "scale", Vector2.ONE * 1.08, duration * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.12)
	tween.tween_interval(duration * 0.35)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.35)
	tween.tween_callback(func():
		if is_instance_valid(label): label.queue_free())
	return tween


func _impact_burst(at: Vector2, color: Color) -> void:
	_ensure_layer()
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2.ONE * settings.impact_burst_size
	ring.pivot_offset = ring.size * 0.5
	ring.global_position = at - ring.size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.12)
	style.border_color = Color(color, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(settings.impact_burst_size * 0.5))
	ring.add_theme_stylebox_override("panel", style)
	effects_root.add_child(ring)
	ring.scale = Vector2.ONE * 0.25
	var tween := _track(create_tween().bind_node(ring))
	var duration := _duration(settings.impact_burst_duration)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.35, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)


func _system_flash(color: Color, duration: float) -> void:
	_ensure_layer()
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color, 0.0)
	effects_root.add_child(flash)
	var tween := _track(create_tween().bind_node(flash))
	var d := _duration(duration)
	tween.tween_property(flash, "color:a", 0.22, d * 0.35)
	tween.tween_property(flash, "color:a", 0.0, d * 0.65)
	tween.tween_callback(flash.queue_free)


func _scanline(color: Color) -> void:
	_ensure_layer()
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color(color, 0.48)
	line.size = Vector2(maxf(effects_root.size.x, 1280.0), 5.0)
	line.position = Vector2(0, -line.size.y)
	effects_root.add_child(line)
	var tween := _track(create_tween().bind_node(line))
	tween.tween_property(line, "position:y", maxf(effects_root.size.y, 720.0) + line.size.y, _duration(settings.scanline_duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(line.queue_free)


func screen_shake(target: Control, intensity: float = -1.0, duration: float = -1.0) -> Tween:
	if not is_instance_valid(target): return null
	var key := target.get_instance_id()
	if not _shakes.has(key): _shakes[key] = {"ref": weakref(target), "position": target.position, "offsets": {}}
	_shake_serial += 1
	var serial := _shake_serial
	var state: Dictionary = _shakes[key]
	var tween := _track(create_tween())
	var shake_duration := _duration(settings.shake_duration if duration < 0.0 else duration)
	var shake_intensity := settings.shake_intensity if intensity < 0.0 else intensity
	state.offsets[serial] = Vector2.ZERO
	tween.tween_method(func(weight: float): _set_shake_offset(key, serial, weight, shake_intensity), 0.0, 1.0, shake_duration)
	tween.tween_callback(func(): _finish_shake(key, serial))
	return tween


func clear() -> void:
	for tween in _tweens: tween.kill()
	_tweens.clear()
	for key in _hover.keys():
		var state: Dictionary = _hover[key]
		var view: Control = state.ref.get_ref()
		if is_instance_valid(view):
			view.position = state.position
			view.scale = state.scale
			view.pivot_offset = state.pivot
	_hover.clear()
	for key in _restores.keys():
		var state: Dictionary = _restores[key]
		var control: Control = state.ref.get_ref()
		if is_instance_valid(control):
			control.position = state.position
			control.scale = state.scale
			control.rotation = state.rotation
			control.modulate = state.modulate
			control.pivot_offset = state.pivot
			_remove_flashes(control)
	_restores.clear()
	_actor_effects.clear()
	for key in _flash_targets.keys():
		var flash_target: Control = _flash_targets[key].ref.get_ref()
		if is_instance_valid(flash_target): _remove_flashes(flash_target)
	_flash_targets.clear()
	for key in _shakes.keys():
		var state: Dictionary = _shakes[key]
		var control: Control = state.ref.get_ref()
		if is_instance_valid(control): control.position = state.position
	_shakes.clear()
	if is_instance_valid(effects_root):
		for child in effects_root.get_children(): child.queue_free()


func _ensure_layer() -> void:
	if is_instance_valid(effects_layer): return
	effects_layer = CanvasLayer.new()
	effects_layer.layer = 20
	effects_layer.name = "GameFeelEffects"
	effects_root = Control.new()
	effects_root.name = "EffectsRoot"
	effects_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(effects_root)
	add_child(effects_layer)


func _strip_interaction(node: Node) -> void:
	node.set_script(null)
	# Controls must still allow bound Tweens to process. Scripts/input are removed.
	node.process_mode = Node.PROCESS_MODE_INHERIT if node is Control else Node.PROCESS_MODE_DISABLED
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): _strip_interaction(child)


func _track(tween: Tween) -> Tween:
	_tweens = _tweens.filter(func(item: Tween): return item.is_valid())
	for states in [_hover, _restores, _shakes]:
		for key in states.keys():
			if not is_instance_valid(states[key].ref.get_ref()): states.erase(key)
	for key in _actor_effects.keys():
		if not _actor_effects[key].is_valid(): _actor_effects.erase(key)
	for key in _flash_targets.keys():
		if not is_instance_valid(_flash_targets[key].ref.get_ref()): _flash_targets.erase(key)
	_tweens.append(tween)
	tween.finished.connect(func(): _tweens.erase(tween))
	return tween


func _kill_hover(key: int) -> void:
	if _hover.has(key) and _hover[key].has("tween"):
		var tween: Tween = _hover[key].tween
		if tween:
			tween.kill()
			_tweens.erase(tween)


func _finish_hover(key: int) -> void:
	if not _hover.has(key): return
	var state: Dictionary = _hover[key]
	var view: Control = state.ref.get_ref()
	if is_instance_valid(view): view.pivot_offset = state.pivot
	_hover.erase(key)


func _remember(control: Control) -> Dictionary:
	var key := control.get_instance_id()
	if not _restores.has(key): _restores[key] = {"ref": weakref(control), "position": control.position, "scale": control.scale, "rotation": control.rotation, "modulate": control.modulate, "pivot": control.pivot_offset}
	return _restores[key]


func _restore(control: Control) -> void:
	if not is_instance_valid(control): return
	var key := control.get_instance_id()
	if not _restores.has(key): return
	var state: Dictionary = _restores[key]
	control.position = state.position
	control.scale = state.scale
	control.rotation = state.rotation
	control.modulate = state.modulate
	control.pivot_offset = state.pivot
	_remove_flashes(control)
	_restores.erase(key)


func _flash(control: Control, color: Color, duration: float) -> void:
	if not is_instance_valid(control): return
	_remove_flashes(control)
	_flash_targets[control.get_instance_id()] = {"ref": weakref(control), "modulate": control.modulate}
	var original := control.modulate
	var player := AnimationPlayer.new()
	player.set_meta("_game_feel_flash", true)
	control.add_child(player)
	player.root_node = NodePath("..")
	var animation := Animation.new()
	animation.length = _duration(duration)
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(":modulate"))
	animation.track_insert_key(track, 0.0, original)
	animation.track_insert_key(track, animation.length * 0.35, color)
	animation.track_insert_key(track, animation.length, original)
	var library := AnimationLibrary.new()
	library.add_animation("flash", animation)
	player.add_animation_library("", library)
	player.animation_finished.connect(func(_name: StringName):
		if is_instance_valid(control): _remove_flashes(control))
	player.play("flash")


func _remove_flashes(control: Control) -> void:
	if not is_instance_valid(control): return
	for child in control.get_children():
		if child is AnimationPlayer and child.get_meta("_game_feel_flash", false):
			child.stop()
			child.queue_free()
	if _flash_targets.has(control.get_instance_id()): control.modulate = _flash_targets[control.get_instance_id()].modulate
	_flash_targets.erase(control.get_instance_id())


func _popup_motion(popup: Control, duration: float) -> void:
	if not is_instance_valid(popup): return
	var tween := _track(create_tween().bind_node(popup))
	var popup_duration := _duration(duration)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(popup, "position:y", popup.position.y - 28.0, popup_duration)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, popup_duration)
	tween.tween_callback(func():
		if is_instance_valid(popup): popup.queue_free())


func _replace_actor_effect(actor: Control) -> void:
	if not is_instance_valid(actor): return
	var key := actor.get_instance_id()
	if _actor_effects.has(key):
		var prior: Tween = _actor_effects[key]
		if prior:
			prior.kill()
			_tweens.erase(prior)
		_actor_effects.erase(key)
	_restore(actor)


func _center_pivot(control: Control) -> void:
	if is_instance_valid(control): control.pivot_offset = control.size * 0.5


func _center_target(control: Control, global_center: Vector2) -> Vector2:
	var parent := control.get_parent() as CanvasItem
	var local_center := parent.get_global_transform().affine_inverse() * global_center if parent else global_center
	return local_center - control.size * 0.5


func _effective_theme(source: Control) -> Theme:
	var current: Control = source
	while current:
		if current.theme: return current.theme
		current = current.get_parent() as Control
	return source.get_theme()


func _damage_popup(amount: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("ffdd8a"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_root.add_child(label)
	label.global_position = at
	return label


func _text_popup(message: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("f6d786"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("18282b")
	background.set_content_margin_all(4)
	background.set_corner_radius_all(4)
	label.add_theme_stylebox_override("normal", background)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_root.add_child(label)
	label.global_position = at
	return label


func _set_shake_offset(key: int, serial: int, weight: float, magnitude: float) -> void:
	if not _shakes.has(key): return
	var state: Dictionary = _shakes[key]
	var control: Control = state.ref.get_ref()
	if not is_instance_valid(control):
		_shakes.erase(key)
		return
	var fade := 1.0 - weight
	state.offsets[serial] = Vector2(sin(weight * 37.0 + serial) * magnitude * fade, cos(weight * 53.0 + serial) * magnitude * fade)
	_apply_shake(state, control)


func _finish_shake(key: int, serial: int) -> void:
	if not _shakes.has(key): return
	var state: Dictionary = _shakes[key]
	state.offsets.erase(serial)
	var control: Control = state.ref.get_ref()
	if not is_instance_valid(control):
		_shakes.erase(key)
		return
	if state.offsets.is_empty():
		control.position = state.position
		_shakes.erase(key)
	else:
		_apply_shake(state, control)


func _apply_shake(state: Dictionary, control: Control) -> void:
	var offset := Vector2.ZERO
	for value in state.offsets.values(): offset += value
	control.position = state.position + offset


func _duration(value: float) -> float:
	return maxf(value, EPSILON)
