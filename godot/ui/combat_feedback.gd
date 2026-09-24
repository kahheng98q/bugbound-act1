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
var _bee_pose := Vector2(0.0, -1.0)
var _transition_backdrop: Control
var _presenting_result := false
var _enemy_attack_visual: Control
var _enemy_attack_target := Vector2.ZERO
var _enemy_attack_armed := false

func prepare_card(id: int, data: Dictionary) -> void:
	if not cards.has(id) or not is_instance_valid(cards[id]): return
	if cards[id].get_parent().size.y <= 0: return
	_flight = feel.snapshot(cards[id])
	var target := enemy if data.get("kind", "") == "attack" else player
	_target = target.get_global_rect().get_center() if is_instance_valid(target) else screen.size * 0.5
	if data.get("kind", "") == "attack" and is_instance_valid(player): player.attack()

func prepare_enemy_attack() -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(player): return
	if enemy.size.x <= 0 or player.size.x <= 0: return
	_enemy_attack_visual = feel.snapshot(enemy)
	_enemy_attack_target = player.get_global_rect().get_center()
	_enemy_attack_armed = is_instance_valid(_enemy_attack_visual)


func before_render(run: RunState) -> void:
	_pending = {}
	if is_instance_valid(player): _bee_pose = Vector2(player.idle_time, player.attack_time)
	var resolved := _battle != null and run.battle == null and (_battle.enemy_hp <= 0 or _battle.hp <= 0)
	if _presenting_result and not resolved:
		_epoch += 1
		feel.clear()
		_presenting_result = false
	if resolved and is_instance_valid(screen.content):
		_presenting_result = true
		# Retain the arena until its effects finish; rewards never sit underneath them.
		var hide_enemy := _battle.enemy_hp <= 0 and is_instance_valid(enemy)
		if hide_enemy: enemy.hide()
		_transition_backdrop = feel.snapshot(screen.content)
		feel.effects_root.move_child(_transition_backdrop, 0)
		if hide_enemy: enemy.show()
	if (_battle != run.battle or run.screen != _screen_name) and not resolved:
		_epoch += 1
		feel.clear()
		_flight = null
		_bee_pose = Vector2(0.0, -1.0)
	if _battle != null and (run.battle == _battle or resolved):
		_pending = {
			"epoch": _epoch, "battle_id": _battle.get_instance_id(),
			"damage": maxi(0, _enemy_hp - _battle.enemy_hp),
			"player_damage": maxi(0, _player_hp - _battle.hp),
			"dead": _enemy_hp > 0 and _battle.enemy_hp <= 0,
			"enemy_attack": _enemy_attack_armed,
			"enemy_attack_visual": _enemy_attack_visual,
			"enemy_attack_target": _enemy_attack_target,
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
	_enemy_attack_armed = false
	_enemy_attack_visual = null
	# The old Controls are about to be freed by the UI rebuild.
	enemy = null
	player = null
	monitor = null
	progress = null
	cards.clear()

func after_render(run: RunState) -> void:
	if is_instance_valid(player): player.restore_pose(_bee_pose)
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
	if is_instance_valid(_transition_backdrop):
		_reveal_after_effects(screen.content, _transition_backdrop)
		_transition_backdrop = null

func _reveal_after_effects(next_content: Control, backdrop: Control) -> void:
	next_content.hide()
	# _present defers two frames for layout; let every effect start first.
	for i in range(4): await get_tree().process_frame
	while is_instance_valid(backdrop) and feel.effects_root.get_child_count() > 1:
		await get_tree().process_frame
	if is_instance_valid(backdrop): backdrop.queue_free()
	if is_instance_valid(next_content):
		_presenting_result = false
		next_content.show()
		next_content.modulate.a = 0
		next_content.create_tween().tween_property(next_content, "modulate:a", 1.0, maxf(0.001, feel.settings.screen_enter_duration))

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
	if batch.get("enemy_attack", false) and is_instance_valid(batch.get("enemy_attack_visual")):
		feel.enemy_attack(batch.enemy_attack_visual, batch.enemy_attack_target, batch.player_damage, screen, player)
	elif batch.player_damage > 0:
		feel.screen_shake(screen)
	if is_instance_valid(batch.get("monitor")):
		var copy: Control = batch.monitor
		copy.show()
		batch.icon.show()
		feel.monitor_complete(copy, batch.progress, batch.text, batch.icon, batch.target).finished.connect(copy.queue_free)
