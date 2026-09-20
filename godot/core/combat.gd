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
		_: intent = {"damage": 13 if value < .3 else 8, "block": 0, "label": "FULL SCAN" if value < .3 else "QUICK SCAN"}

func intent_damage() -> int:
	return intent.damage + strength + (threat * 2 if enemy_key == "antivirus" else 0)

func damage_enemy(amount: int) -> void:
	var absorbed := mini(enemy_shield, amount)
	enemy_shield -= absorbed
	enemy_hp = maxi(0, enemy_hp - amount + absorbed)

func can_play(card: Dictionary) -> bool:
	if popup_open or not choice.is_empty() or hp <= 0 or enemy_hp <= 0 or card.cost > energy:
		return false
	if card.key == "jelly":
		return bee.nectar >= 2 and hand.any(func(other): return other.id != card.id and other.cost > 0)
	return true

func play(id: int) -> bool:
	var found := hand.filter(func(card): return card.id == id)
	if found.is_empty() or not can_play(found[0]):
		return false
	var card: Dictionary = found[0]
	hand.erase(card)
	energy -= card.cost
	var energy_after_spend := energy
	var damage: int = 3 * (1 + bee.nectar) if card.key == "swarm" else card.get("damage", 0)
	var gained_block: int = card.get("block", 0)
	if card.key == "swarm": bee.nectar = 0
	if bee.pollen == 2:
		bee.damage = int(floor(damage / 2.0))
		bee.block = int(floor(gained_block / 2.0))
		bee.pollen = 1
	elif bee.pollen == 1:
		damage += bee.damage
		gained_block += bee.block
		bee.pollen = 0
	if enemy_key == "cursor" and card.kind == "attack" and attacks == 0:
		damage = maxi(0, damage - 3)
	damage_enemy(damage)
	block += gained_block
	hp = maxi(0, mini(run.max_hp, hp + card.get("heal", 0)) - card.get("selfDamage", 0))
	energy += card.get("energy", 0)
	draw(card.get("draw", 0))
	if not card.get("exhausted", false) and card.key != "sting": discard.append(card)
	if card.key == "sting":
		for i in range(run.cards.size()):
			if run.cards[i].key == "sting":
				run.cards.remove_at(i)
				break
	if card.kind == "attack" and attacks == 0: bee.nectar += 1
	match card.key:
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
	if card.kind == "attack": attacks += 1
	log.push_front(card.name + " // " + Catalog.describe(card))
	var triggered := false
	match bug:
		"overflow": triggered = card.cost > 0 and energy_after_spend == 0
		"memory": triggered = card.get("draw", 0) > 0 or (card.key == "waggle" and not choice.is_empty())
		"hotPath":
			if card.kind == "attack": progress += 1
			triggered = progress >= 2
		"firewall": triggered = gained_block >= 5
		"loop":
			progress += 1
			triggered = progress >= 3
	if triggered: trigger_bug()
	return true

func trigger_bug() -> void:
	var old_bug := bug
	match bug:
		"overflow":
			draw(2)
			energy += 1
			strength += 1
		"memory":
			draw(2)
			hp = maxi(0, hp - 2)
		"hotPath":
			damage_enemy(6)
			hp = maxi(0, hp - 2)
		"firewall":
			block += 8
			debt += 1
		"loop":
			energy += 2
			hp = maxi(0, hp - 3)
	triggers += 1
	if enemy_key == "frozen": enemy_shield += 3
	if enemy_key == "memoryHog" and triggers % 2 == 0: strength += 2
	if enemy_key == "antivirus": threat = mini(6, threat + 1)
	bug = run.rng.pick(Catalog.BUG_KEYS.filter(func(key): return key != old_bug))
	progress = 0
	log.push_front("BUG MUTATED: %s → %s" % [Catalog.data.bugs[old_bug].name, Catalog.data.bugs[bug].name])

func end_turn() -> bool:
	if popup_open or not choice.is_empty() or hp <= 0 or enemy_hp <= 0: return false
	var taken := maxi(0, intent_damage() - block)
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
	energy = maxi(0, 3 - debt) + bee.bank
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
