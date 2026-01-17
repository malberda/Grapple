extends CharacterBody2D

var scaling_factor: float = 8.0;

# --------------------
# CAMERA 
# --------------------
@export var camera_pull_strength := 0.1
@export var camera_pull_smoothing := 12.0
@export var max_camera_offset := 36.0
@onready var camera: Camera2D = $Camera

# --------------------
# MOVEMENT 
# --------------------
@export var run_speed := 2100.0
@export var accel := 8000.0
@export var air_accel := 4800.0
@export var friction := 7000.0
@export var gravity := 6000.0
@export var jump_velocity := -2400.0
@export var jump_cut_multiplier := 0.35

# --------------------
# DOUBLE JUMP
# --------------------
@export var double_jump_horizontal_speed := 2200.0  # max horizontal gain
@export var double_jump_vertical_speed := -2200.0   # initial vertical
@export var double_jump_acceleration := 6000.0    # how fast horizontal reaches max
@export var double_jump_max_hold_time := 0.3      # how long you can hold for max momentum
@export var double_jump_velocity := -2000.0
@export var double_jump_cut_multiplier := 2.8
var double_jump_holding := false
var double_jump_hold_timer := 0.0
var can_double_jump := false
var can_wall_jump := false
@export var wall_jump_x_velocity = 1500.0

# --------------------
# AIR DASH
# --------------------
@export var airdash_speed := 2600.0
@export var airdash_time := 0.15       # duration of dash
@export var airdash_cooldown := 0.25   # optional: cooldown before next dash
var airdash_timer := 0.0
var can_airdash := true
var airdash_direction := Vector2.ZERO
var last_input_x := 1  # Default facing right


# --------------------
# GENERAL USE
# --------------------
var coyote_timer = 0.0
var coyote_time = .1  #coyote timing for jump
var prev_global_position


func _ready():
	floor_max_angle = deg_to_rad(50)
	prev_global_position = self.global_position
	
func _process(_delta):
	var vel = prev_global_position - self.global_position
	prev_global_position = self.global_position
	
	if vel.x == 0 and vel.y == 0:
		$AnimatedSprite2D.stop()
	elif !is_on_floor():
		$AnimatedSprite2D.pause()
	else:
		$AnimatedSprite2D.play('default')
		if vel.x > 0:
			$AnimatedSprite2D.flip_h = false
		else:
			$AnimatedSprite2D.flip_h = true

# --------------------
# INPUT
# --------------------
func _input(event):
	if event.is_action_pressed("airDash") and can_airdash:# and not is_on_floor():
		var input_dir = Vector2(
			Input.get_axis("left", "right"),
			0
		)
		if input_dir == Vector2.ZERO:
			input_dir.x = last_input_x * scaling_factor # default 1/-1
		airdash_direction = input_dir.normalized()
		airdash_timer = airdash_time
		can_airdash = false

	if event.is_action_pressed("reset_level"):
		get_tree().reload_current_scene()	
	
	if event.is_action_released('jump') and velocity.y < 0:
		velocity.y *= jump_cut_multiplier
	
	if event.is_action_pressed("jump"):
		# DOUBLE JUMP
		var is_air_jump = not is_on_floor() and coyote_timer <= 0.0 and can_double_jump
		if is_air_jump:
			velocity.y = double_jump_vertical_speed
			can_double_jump = false
			double_jump_holding = true
			double_jump_hold_timer = double_jump_max_hold_time
			
		if can_wall_jump:
			can_double_jump = true
			if get_slide_collision_count() > 0:
				var normal = get_slide_collision(0).get_normal()
				var wall_direction = sign(normal.x)  # +1 for left wall, -1 for right wall			
				if wall_direction > 0:
					# Wall is on left
					velocity.x = wall_jump_x_velocity
				else:
					# Wall is on right
					velocity.x = 0 - wall_jump_x_velocity
			
			velocity.y = double_jump_vertical_speed
	
	if event.is_action_released("jump") and velocity.y < 0 and double_jump_holding:
		velocity.y *= double_jump_cut_multiplier
		double_jump_holding = false

# --------------------
# PHYSICS LOOP
# --------------------
func _physics_process(delta):
	if is_on_floor():
		can_airdash = true
		can_double_jump = true

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Apply airdash if active
	if airdash_timer > 0:
		velocity = airdash_direction * airdash_speed
		airdash_timer -= delta
		
	if double_jump_holding and double_jump_hold_timer > 0:
		var input_x := Input.get_axis("left", "right")
		if input_x != 0:
			var target_horiz = input_x * double_jump_horizontal_speed
			velocity.x = move_toward(velocity.x, target_horiz, double_jump_acceleration * delta)
		double_jump_hold_timer -= delta

	apply_movement(delta)
	move_and_slide()

# --------------------
# NORMAL MOVEMENT
# --------------------
func apply_movement(delta):
	var input_x := Input.get_axis("left", "right")
	if input_x != 0:
		last_input_x = sign(input_x)
	var target_speed := input_x * run_speed
	var current_accel := accel if is_on_floor() else air_accel

	if input_x != 0:
		velocity.x = move_toward(velocity.x, target_speed, current_accel * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	velocity.y += gravity * delta
	
	if !is_on_floor() and is_on_wall():
		velocity.y -= 100.0
		can_wall_jump = true
	else:
		can_wall_jump = false

	if (is_on_floor() or coyote_timer > 0) and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		coyote_timer = 0.0
