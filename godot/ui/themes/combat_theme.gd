@tool
extends Theme
## Script-backed Theme: token edits apply to every resource consumer on reload.
const VISUAL = preload("res://ui/bugbound_theme.gd")

func _init() -> void:
	VISUAL.populate_theme(self)
