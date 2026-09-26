extends TextureRect
## Registered artwork frames: eight idle poses, then eight attack poses.
const SHEET = preload("res://assets/bee-animation.png")
const IDLE_FRAME_SECONDS := 0.20
const ATTACK_FRAME_SECONDS := 0.10
var idle_time := 0.0
var attack_time := -1.0
var frame_index := -1
var atlas := AtlasTexture.new()

func _init() -> void:
	atlas.atlas = SHEET
	atlas.filter_clip = true
	texture = atlas
	_update_frame()

func _process(delta: float) -> void:
	idle_time += delta
	if attack_time >= 0.0:
		attack_time += delta
		if attack_time >= 8 * ATTACK_FRAME_SECONDS: attack_time = -1.0
	_update_frame()

func attack() -> void:
	attack_time = 0.0
	_update_frame()

func restore_pose(pose: Vector2) -> void:
	idle_time = pose.x
	attack_time = pose.y
	_update_frame()

func _update_frame() -> void:
	var next := 8 + mini(7, int(attack_time / ATTACK_FRAME_SECONDS)) if attack_time >= 0.0 else int(idle_time / IDLE_FRAME_SECONDS) % 8
	if next == frame_index: return
	frame_index = next
	var cell := Vector2(SHEET.get_size()) / 4.0
	atlas.region = Rect2(Vector2(frame_index % 4, frame_index / 4) * cell, cell)
