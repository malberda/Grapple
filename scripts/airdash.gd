extends Node

# --------------------
# AIR DASH
# --------------------
@export var airdash_speed := 650.0 * 8
@export var airdash_time := 0.15       # duration of dash
@export var airdash_cooldown := 0.25   # optional: cooldown before next dash
var airdash_timer := 0.0
var can_airdash := true
var airdash_direction := Vector2.ZERO
var last_input_x := 1  # Default facing right
