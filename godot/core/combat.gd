class_name Combat
extends RefCounted
## Battle-local state and rules. Only play() evaluates bugs; rewards never chain.
var run: RefCounted
var enemy_key: String
var enemy_hp: int
var enemy_shield := 0
var strength := 0
var hp: int
var block := 0
var energy := 3
var turn := 1
var deck: Array = []
var discard: Array = []
var hand: Array = []
var bug: String
var progress := 0
var triggers := 0
var debt := 0
var attacks := 0
var threat := 0
var intent: Dictionary
var popup_turn: int
var popup_open := false
var popup_resolved := false
var choice: Dictionary = {}
var log: Array[String] = []
var bee := {"nectar": 0, "bank": 0, "pollen": 0, "damage": 0, "block": 0, "comb": 0, "compiling": false, "first": {}, "guard": 0}
var web: Array[String] = []
var web_trap := false
var breakpoint_armed := false

func _init(owner_run: RefCounted, key: String) -> void:
	run = owner_run
	enemy_key = key
	enemy_hp = Catalog.data.enemies[key].hp
	hp = run.hp
	block = run.flags.startingBlock
	strength = int(run.flags.daemonDraw > 0) + int(run.flags.printerDebt)
	for template in run.cards:
		var card: Dictionary = template.duplicate(true)
		card.id = run.serial
		run.serial += 1
		deck.append(card)
	deck = run.rng.shuffled(deck)
	bug = run.rng.pick(Catalog.BUG_KEYS)
	popup_turn = 2 + int(floor(run.rng.next() * 3))
	draw(5 + run.flags.daemonDraw)
	next_intent()
	run.flags.daemonDraw = 0
	run.flags.startingBlock = 0
	run.flags.printerDebt = false
	log.append("ACTIVE BUG: " + Catalog.data.bugs[bug].name)

func draw(count: int) -> void:
	for i in range(count):
		if deck.is_empty():
			if discard.is_empty():
				return
			deck = run.rng.shuffled(discard)
			discard = []
		hand.append(deck.pop_front())

func next_intent() -> void:
	var value: float = run.rng.next()
	match enemy_key:
		"folder": intent = {"damage": 5 if value < .35 else 7, "block": 8 if value < .35 else 0, "label": "backup + attack" if value < .35 else "file throw"}
		"cursor": intent = {"damage": 10 if value < .45 else 6, "block": 0, "label": "double click" if value < .45 else "pointer thrust"}
		"trash": intent = {"damage": 6 + int(floor(turn / 2.0)) * 2 + (3 if value < .22 else 0), "block": 0, "label": "empty recycle bin" if value < .22 else "trash buildup"}
		"frozen": intent = {"damage": 5 if value < .42 else 9, "block": 7 if value < .42 else 0, "label": "freeze + attack" if value < .42 else "not responding"}
		"memoryHog": intent = {"damage": 14 if value < .3 else 9, "block": 0, "label": "memory peak" if value < .3 else "memory theft"}
		"sentinel": intent = {"damage": 6 if turn % 2 == 1 else 11, "block": 8 if turn % 2 == 1 else 0, "label": "raise firewall" if turn % 2 == 1 else "firewall discharge"}
		"wasp": intent = {"damage": 14 if turn % 3 == 0 else 4, "block": 0, "label": "clock strike" if turn % 3 == 0 else "winding gears"}
		_: intent = {"damage": 13 if value < .3 else 8, "block": 0, "label": "FULL SCAN" if value < .3 else "QUICK SCAN"}

func intent_damage() -> int:
	return intent.damage + strength + (threat * 2 if enemy_key == "antivirus" else 0)

func incoming_damage() -> int:
	return maxi(0, intent_damage() - block)

func is_spider() -> bool:
	return run.loadout_key == "spider"

func card_effects(card: Dictionary) -> Dictionary:
	var damage: int = 3 * (1 + bee.nectar) if card.key == "swarm" else card.get("damage", 0)
	var gained_block: int = card.get("block", 0)
	if card.get("consumeCaptured", false) and not web.is_empty():
		damage += card.get("capturedBonusDamage", 0)
	if card.get("consumeAllCaptured", false):
		damage += card.get("capturedDamage", 0) * web.size()
	match card.get("scaling", ""):
		"nectar_damage": damage += 2 * bee.nectar
		"nectar_block": gained_block += 2 * bee.nectar
		"block_damage": damage += mini(block, 12)
		"attacks_damage": damage += 3 * attacks
	if bee.pollen == 1:
		damage += bee.damage
		gained_block += bee.block
	var pollen_damage := damage
	if enemy_key == "cursor" and card.kind == "attack" and attacks == 0:
		damage = maxi(0, damage - 3)
	return {"damage": damage, "block": gained_block, "pollen_damage": pollen_damage}

func bug_matches(card: Dictionary, gained_block: int, energy_after_spend: int, has_draw_choice: bool) -> bool:
	match bug:
		"overflow": return card.cost > 0 and energy_after_spend == 0
		"memory": return card.get("draw", 0) > 0 or (card.key == "waggle" and has_draw_choice)
		"hotPath": return progress + int(card.kind == "attack") >= 2
		"firewall": return gained_block >= 5
		"loop": return progress + 1 >= 3
	return false

func next_turn_energy() -> int:
	return maxi(0, 3 - debt) + bee.bank

func unplayable_reason(card: Dictionary) -> String:
	if hp <= 0 or enemy_hp <= 0:
		return "Battle ended"
	if popup_open or not choice.is_empty():
		return "Resolve the current choice first"
	if card.cost > energy:
		return "Not enough energy"
	if card.key == "jelly":
		if bee.nectar < 2:
			return "Need 2 Nectar"
		if not hand.any(func(other): return other.get("id", -1) != card.get("id", -1) and other.cost > 0):
			return "No eligible target"
	if card.get("releaseCaptured", false) and web.is_empty():
		return "Web is empty"
	return ""

func preview_card(card: Dictionary) -> Dictionary:
	# Read-only: shares rule calculations and never draws cards or advances RNG.
	var effects := card_effects(card)
	var reason := unplayable_reason(card)
	effects.unplayable_reason = reason
	effects.triggers_bug = reason.is_empty() and bug_matches(card, effects.block, energy - card.cost,
		not deck.is_empty() or not discard.is_empty() or not card.get("exhausted", false))
	effects.nectar_spent = bee.nectar if card.key == "swarm" else (2 if card.key == "jelly" else 0)
	effects.captured_spent = web.size() if card.get("consumeAllCaptured", false) else (1 if card.get("consumeCaptured", false) and not web.is_empty() else 0)
	effects.bug_consequences = bug_consequences(is_spider() and breakpoint_armed) if effects.triggers_bug else empty_bug_consequences()
	var projected_debt: int = debt + effects.bug_consequences.debt
	var projected_bank: int = bee.bank
	if card.key == "nectar":
		projected_bank += energy - card.cost
	effects.next_turn_debt = projected_debt
	effects.next_turn_bank = projected_bank
	effects.next_turn_energy = maxi(0, 3 - projected_debt) + projected_bank
	if bee.compiling and bee.comb == 5:
		var first: Dictionary = bee.first
		effects.compiler_consequences = {"damage": first.get("damage", 0), "block": first.get("block", 0), "draw": first.get("draw", 0), "hp_loss": 0, "heal": first.get("heal", 0)}
	return effects

func damage_enemy(amount: int) -> void:
	var absorbed := mini(enemy_shield, amount)
	enemy_shield -= absorbed
	enemy_hp = maxi(0, enemy_hp - amount + absorbed)

func can_play(card: Dictionary) -> bool:
	return unplayable_reason(card).is_empty()

func play(id: int) -> bool:
	var found := hand.filter(func(card): return card.get("id", -1) == id)
	if found.is_empty() or not can_play(found[0]):
		return false
	var card: Dictionary = found[0]
	hand.erase(card)
	energy -= card.cost
	var energy_after_spend := energy
	var effects := card_effects(card)
	var damage: int = effects.damage
	var gained_block: int = effects.block
	if card.key == "swarm": bee.nectar = 0
	if bee.pollen == 2:
		bee.damage = int(floor(effects.pollen_damage / 2.0))
		bee.block = int(floor(gained_block / 2.0))
		bee.pollen = 1
	elif bee.pollen == 1:
		bee.pollen = 0
	if enemy_key == "sentinel" and card.kind == "skill":
		enemy_shield = maxi(0, enemy_shield - 2)
	damage_enemy(damage)
	block += gained_block
	hp = maxi(0, mini(run.max_hp, hp + card.get("heal", 0)) - card.get("selfDamage", 0))
	energy += card.get("energy", 0)
	draw(card.get("draw", 0))
	if not card.get("exhausted", false) and card.key != "sting": discard.append(card)
	if card.get("consumeCaptured", false) and not web.is_empty(): web.pop_front()
	if card.get("consumeAllCaptured", false): web.clear()
	if card.get("releaseCaptured", false) and not web.is_empty(): release_captured_bug(web.pop_front())
	if card.key == "sting":
		for i in range(run.cards.size()):
			if run.cards[i].key == "sting":
				run.cards.remove_at(i)
				break
	if not is_spider() and card.kind == "attack" and attacks == 0: bee.nectar += 1
	if not is_spider(): bee.nectar += card.get("nectarGain", 0)
	match card.key:
		"web_trap": web_trap = true
		"breakpoint": breakpoint_armed = true
		"nectar":
			bee.bank += energy
			energy = 0
			bee.nectar += 1
		"pollen": bee.pollen = 2
		"guard": bee.guard += 8
		"jelly":
			bee.nectar -= 2
			choice = {"kind": "jelly"}
		"waggle":
			var inspected: Array = []
			for i in range(3):
				if deck.is_empty() and not discard.is_empty():
					deck = run.rng.shuffled(discard)
					discard = []
				if not deck.is_empty(): inspected.append(deck.pop_front())
			if not inspected.is_empty(): choice = {"kind": "waggle", "cards": inspected, "drawn": false, "ordered": []}
	if bee.compiling:
		if bee.comb == 0: bee.first = card.duplicate(true)
		bee.comb += 1
		if bee.comb == 6:
			damage_enemy(bee.first.get("damage", 0))
			block += bee.first.get("block", 0)
			hp = mini(run.max_hp, hp + bee.first.get("heal", 0))
			draw(bee.first.get("draw", 0))
			bee.comb = 0
			bee.first = {}
	if card.key == "comb": bee.compiling = true
	var triggered := bug_matches(card, gained_block, energy_after_spend, not choice.is_empty())
	if bug == "hotPath" and card.kind == "attack": progress += 1
	if bug == "loop": progress += 1
	if card.kind == "attack": attacks += 1
	log.push_front(card.name + " // " + Catalog.describe(card))
	if triggered: trigger_bug()
	return true

func empty_bug_consequences() -> Dictionary:
	return {"damage": 0, "block": 0, "draw": 0, "energy": 0, "hp_loss": 0, "debt": 0, "enemy_strength": 0}

func bug_consequences(ignore_risk := false) -> Dictionary:
	var consequences := empty_bug_consequences()
	match bug:
		"overflow":
			consequences.draw = 2
			consequences.energy = 1
			consequences.enemy_strength = 1
		"memory":
			consequences.draw = 2
			consequences.hp_loss = 2
		"hotPath":
			consequences.damage = 6
			consequences.hp_loss = 2
		"firewall":
			consequences.block = 8
			consequences.debt = 1
		"loop":
			consequences.energy = 2
			consequences.hp_loss = 3
	if ignore_risk:
		consequences.hp_loss = 0
		consequences.debt = 0
		consequences.enemy_strength = 0
	if enemy_key == "memoryHog" and (triggers + 1) % 2 == 0:
		consequences.enemy_strength += 2
	return consequences

func capture_bug(key: String) -> void:
	if not is_spider(): return
	if web_trap:
		web.clear()
		web.append(key)
		web.append(key)
		web_trap = false
		return
	if web.size() >= 2: web.pop_front()
	web.append(key)

func apply_bug_reward(key: String) -> void:
	match key:
		"overflow":
			draw(2)
			energy += 1
		"memory": draw(2)
		"hotPath": damage_enemy(6)
		"firewall": block += 8
		"loop": energy += 2

func release_captured_bug(key: String) -> void:
	apply_bug_reward(key)
	log.push_front("WEB RELEASE: " + Catalog.data.bugs[key].name)

func trigger_bug() -> void:
	var old_bug := bug
	var ignore_risk := is_spider() and breakpoint_armed
	var consequences := bug_consequences(ignore_risk)
	damage_enemy(consequences.damage)
	block += consequences.block
	draw(consequences.draw)
	energy += consequences.energy
	hp = maxi(0, hp - consequences.hp_loss)
	debt += consequences.debt
	strength += consequences.enemy_strength
	triggers += 1
	capture_bug(old_bug)
	breakpoint_armed = false
	if enemy_key == "frozen": enemy_shield += 3
	if enemy_key == "antivirus": threat = mini(6, threat + 1)
	bug = run.rng.pick(Catalog.BUG_KEYS.filter(func(key): return key != old_bug))
	progress = 0
	log.push_front("BUG MUTATED: %s → %s" % [Catalog.data.bugs[old_bug].name, Catalog.data.bugs[bug].name])

func end_turn() -> bool:
	if popup_open or not choice.is_empty() or hp <= 0 or enemy_hp <= 0: return false
	var taken := incoming_damage()
	hp = maxi(0, hp - taken)
	log.push_front("%s: %d damage · HP -%d" % [intent.label, intent_damage(), taken])
	if hp <= 0: return true
	if taken > 0 and bee.guard > 0:
		damage_enemy(bee.guard)
		bee.guard = 0
	if enemy_hp <= 0: return true
	enemy_shield = intent.block
	discard.append_array(hand)
	hand = []
	block = 0
	turn += 1
	energy = next_turn_energy()
	bee.bank = 0
	debt = 0
	attacks = 0
	progress = 0
	draw(5)
	next_intent()
	popup_open = not popup_resolved and turn == popup_turn
	return true

func resolve_popup(allow: bool) -> void:
	if not popup_open: return
	if allow:
		draw(2)
		energy += 1
		hp = maxi(0, hp - 4)
	else:
		block += 9
		debt += 1
	popup_open = false
	popup_resolved = true

func choose_card(id: int) -> void:
	if choice.is_empty(): return
	if choice.kind == "jelly":
		for card in hand:
			if card.id == id and card.cost > 0:
				card.cost -= 1
				choice = {}
				return
	else:
		for card in choice.cards:
			if card.id != id: continue
			choice.cards.erase(card)
			if not choice.drawn:
				hand.append(card)
				choice.drawn = true
			else: choice.ordered.append(card)
			if choice.cards.is_empty():
				deck = choice.ordered + deck
				choice = {}
			return
