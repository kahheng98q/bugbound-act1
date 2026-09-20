extends Node
## Observes resolved state at the UI boundary. No combat action waits for an effect.
var feel: GameFeel
var screen: Control
var enemy: Control
var player: Control
var monitor: Control
var progress: Control
var cards := {}
var completion_text := "BUG COMPLETE!"
var _battle: Combat
var _enemy_hp := 0
var _player_hp := 0
var _triggers := 0
var _epoch := 0
var _flight: Control
var _target := Vector2.ZERO
var _pending := {}
var _screen_name := ""

func prepare_card(id: int, data: Dictionary) -> void:
	if not cards.has(id) or not is_instance_valid(cards[id]): return
	if cards[id].get_parent().size.y <= 0: return
	_flight = feel.snapshot(cards[id])
	var target := enemy if data.get("kind", "") == "attack" else player
	_target = target.get_global_rect().get_center() if is_instance_valid(target) else screen.size * 0.5

func before_render(run: RunState) -> void:
	_pending = {}
	var resolved := _battle != null and run.battle == null and (_battle.enemy_hp <= 0 or _battle.hp <= 0)
	if (_battle != run.battle or run.screen != _screen_name) and not resolved:
		_epoch += 1
		feel.clear()
		_flight = null
	if _battle != null and (run.battle == _battle or resolved):
		_pending = {
			"epoch": _epoch, "battle_id": _battle.get_instance_id(),
			"damage": maxi(0, _enemy_hp - _battle.enemy_hp),
			"player_damage": maxi(0, _player_hp - _battle.hp),
			"dead": _enemy_hp > 0 and _battle.enemy_hp <= 0,
		}
		if _pending.dead and is_instance_valid(enemy):
			_pending.actor = feel.snapshot(enemy)
			_pending.actor.hide()
		if _battle.triggers > _triggers and is_instance_valid(monitor) and monitor.size.y > 0:
			var copy := feel.snapshot(monitor)
			_pending.monitor = copy
			_pending.progress = copy.get_node(monitor.get_path_to(progress))
			_pending.progress.text = progress.get_meta("complete_text", progress.text)
			_pending.text = completion_text
			_pending.target = player.get_global_rect().get_center()
			var icon := Label.new()
			icon.text = "✦"
			icon.add_theme_font_size_override("font_size", 40)
			icon.add_theme_color_override("font_color", Color("e7b94c"))
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			feel.effects_root.add_child(icon)
			_pending.icon = icon
			icon.position = progress.get_global_rect().get_center() - Vector2(22, 22)
			_pending.icon.hide()
			copy.hide()
	# The old Controls are about to be freed by the UI rebuild.
	enemy = null
	player = null
	monitor = null
	progress = null
	cards.clear()

func after_render(run: RunState) -> void:
	_screen_name = run.screen
	_battle = run.battle
	if _battle != null:
		_enemy_hp = _battle.enemy_hp
		_player_hp = _battle.hp
		_triggers = _battle.triggers
	var batch := _pending
	_pending = {}
	if is_instance_valid(_flight):
		feel.card_play(_flight, _target, _present.bind(batch))
		_flight = null
	elif not batch.is_empty():
		_present.call_deferred(batch)

func _present(batch: Dictionary) -> void:
	# Containers finish laying out new portraits before we record their rest pose.
	await get_tree().process_frame
	await get_tree().process_frame
	if batch.is_empty() or batch.epoch != _epoch: return
	var same_battle: bool = _battle != null and _battle.get_instance_id() == batch.battle_id
	if batch.dead and is_instance_valid(batch.get("actor")):
		var actor: Control = batch.actor
		actor.show()
		feel.enemy_damage(actor, batch.damage, func():
			if is_instance_valid(actor): feel.enemy_death(actor, actor.queue_free))
	elif batch.damage > 0 and same_battle and is_instance_valid(enemy):
		feel.enemy_damage(enemy, batch.damage)
	if batch.player_damage > 0:
		feel.screen_shake(screen)
	if is_instance_valid(batch.get("monitor")):
		var copy: Control = batch.monitor
		copy.show()
		batch.icon.show()
		feel.monitor_complete(copy, batch.progress, batch.text, batch.icon, batch.target).finished.connect(copy.queue_free)
