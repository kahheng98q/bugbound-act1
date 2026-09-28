extends TextureRect
## Static Blender prototype; retains the combat presentation interface.
const PORTRAIT = preload("res://assets/characters/bee-programmer.png")
const ATTACK_PULSE_SECONDS := 0.18
var idle_time := 0.0
var attack_time := -1.0

func _init() -> void:
	texture = PORTRAIT
	_apply_pose()

func _process(delta: float) -> void:
	idle_time += delta
	if attack_time >= 0.0:
		attack_time += delta
		if attack_time >= ATTACK_PULSE_SECONDS: attack_time = -1.0
	_apply_pose()

func attack() -> void:
	attack_time = 0.0
	_apply_pose()

func restore_pose(pose: Vector2) -> void:
	idle_time = pose.x
	attack_time = pose.y
	_apply_pose()

func _apply_pose() -> void:
	if attack_time < 0.0:
		scale = Vector2.ONE
		return
	# A brief scale pulse preserves the existing attack hook while this prototype
	# intentionally has a single idle image.
	pivot_offset = size * 0.5
	var phase := clampf(attack_time / ATTACK_PULSE_SECONDS, 0.0, 1.0)
	scale = Vector2.ONE * (1.0 + sin(phase * PI) * 0.035)
