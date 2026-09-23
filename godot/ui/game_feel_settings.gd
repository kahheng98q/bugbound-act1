class_name GameFeelSettings
extends Resource
## Tunable presentation timings for GameFeel. Values are clamped at use time.

@export_category("Card")
@export var hover_duration := 0.12
@export var play_duration := 0.24
@export var anticipation_duration := 0.07
@export var anticipation_lift := 10.0
@export var anticipation_scale := 1.06
@export var play_rotation := 0.12
@export var hover_scale := 1.05
@export var hover_lift := 12.0

@export_category("Combat")
@export var damage_duration := 0.18
@export var damage_popup_duration := 0.60
@export var death_duration := 0.30
@export var flash_duration := 0.10
@export var impact_burst_duration := 0.24
@export var impact_burst_size := 46.0
@export var damage_knockback := 14.0
@export var death_squash := 1.12

@export_category("Rewards")
@export var monitor_duration := 0.38
@export var completion_text_duration := 0.65
@export var reward_fly_duration := 0.42
@export var monitor_flash_duration := 0.16

@export_category("Screen")
@export var screen_enter_duration := 0.18
@export var shake_duration := 0.22
@export var shake_intensity := 8.0
@export var alert_duration := 0.72
@export var alert_flash_duration := 0.12
@export var scanline_duration := 0.34
@export var alert_shake_intensity := 5.0
