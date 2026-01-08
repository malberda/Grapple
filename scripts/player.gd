extends CharacterBody2D

#----------
#maybe do
#----------
#start with nothing/no grapple
#airdash
#double jump
#varying tiles for slickness
#following ghosts from celeste, follow same path and knock you down //figure it out later
#double grapple

#todo:
# add some sort of visual animation for missed grapples. cant fire again till hook returns
# inital rope just swing, no pull. wind waker style
# rocket boost for simple rope. increase early verticality

# --------------------
# EQUIPMENT
# --------------------
var grappleUnlocked = true
var grapplePullUnlocked = false
var rocketBoostUnlocked = true
var airdashUnlocked = true
var doubleJumpUnlocked = true
var doubleHookUnlocked = true
var latchJumpUnlocked = true
enum GrappleState {
	IDLE,
	FIRING,
	LATCHED,
	RETURNING
}
var grapple_state := GrappleState.IDLE
@export var hook_speed := 2000.0
@export var hook_return_speed := 2400.0

var hook_position: Vector2
var hook_velocity: Vector2


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
@export var run_speed := 240.0
@export var accel := 2000.0
@export var air_accel := 1200.0
@export var friction := 1800.0
@export var gravity := 1500.0
@export var jump_velocity := -600.0
@export var jump_cut_multiplier := 0.35


# --------------------
# GRAPPLE
# --------------------
@export var grapple_pull_strength := 3200.0
@export var grapple_damping := 0.99
@export var max_grapple_distance := 400.0
@export var latch_distance := 40
@export var max_rope_length := 400.0
@onready var aim_line: Line2D = $Grapple/AimLine
var coyote_time = .1  #coyote timing for jump
var rope_length := 0.0
var rope_pivot: Vector2
var has_pivot := false

@onready var airdash_helper = preload("res://scripts/airdash.gd").new()
@onready var rocket_boost_helper = preload("res://scripts/rocket_boost.gd").new()

@export var grapple_steering_factor = 4
var valid_grapple_point: Variant

# --------------------
# GENERAL USE
# --------------------
var is_latched := false
var is_grappling := false
var grapple_point: Vector2
var grapple_requested := false
var coyote_timer = 0.0


# --------------------
# VISUALS
# --------------------
@onready var grapple_ray: RayCast2D = $Grapple/GrappleRay
@onready var rope: Line2D = $Grapple/Rope

func _ready():
	floor_max_angle = deg_to_rad(50)

# --------------------
# INPUT
# --------------------
func _input(event):
	if event.is_action_pressed("1"):
		grapplePullUnlocked = !grapplePullUnlocked
	if event.is_action_pressed("2"):
		rocketBoostUnlocked = !rocketBoostUnlocked
	if event.is_action_pressed("3"):
		airdashUnlocked = !airdashUnlocked
	if event.is_action_pressed("4"):
		doubleJumpUnlocked = !doubleJumpUnlocked
	if event.is_action_pressed("5"):
		doubleHookUnlocked = !doubleHookUnlocked
	if event.is_action_pressed("6"):
		latchJumpUnlocked = !latchJumpUnlocked
		
	if event.is_action_pressed("airDash") and airdashUnlocked and airdash_helper.can_airdash:# and not is_on_floor():
		var input_dir = Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("up", "down")
		)
		if input_dir == Vector2.ZERO:
			input_dir.x = airdash_helper.last_input_x # default 1/-1
		airdash_helper.airdash_direction = input_dir.normalized()
		airdash_helper.airdash_timer = airdash_helper.airdash_time
		airdash_helper.can_airdash = false

	
	if event.is_action_released('jump') and velocity.y < 0:
		velocity.y *= jump_cut_multiplier
	
	if event.is_action_pressed("grapple") and grappleUnlocked:
		if grapple_state == GrappleState.IDLE:
			fire_grapple()

		
	if event.is_action_pressed("reset_level"):
		get_tree().reload_current_scene()

	if event.is_action_released("grapple"):
		release_grapple()
		grapple_requested = false

# --------------------
# PHYSICS LOOP
# --------------------
func _physics_process(delta):
	if is_on_floor():
		airdash_helper.can_airdash = true
	update_grapple(delta)
	update_grapple_ray()
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		
	# Only when grappled and rocket boost unlocked
	if is_grappling and Input.is_action_just_pressed("rocketBoost") and rocketBoostUnlocked:
		rocket_boost_helper.rocket_boost_timer = rocket_boost_helper.rocket_boost_duration

	# Apply airdash if active
	if airdash_helper.airdash_timer > 0:
		velocity = airdash_helper.airdash_direction * airdash_helper.airdash_speed
		airdash_helper.airdash_timer -= delta



	if is_latched:
		velocity = Vector2.ZERO  # stick to wall
		if Input.is_action_just_pressed("jump") and latchJumpUnlocked:
			release_grapple()
			velocity.y = jump_velocity
	elif is_grappling:
		apply_grapple_physics(delta)
	else:
		apply_movement(delta)

	move_and_slide()
	update_rope()
	update_aim_line()
	update_camera_pull(delta)

# --------------------
# NORMAL MOVEMENT
# --------------------
func apply_movement(delta):
	var input_x := Input.get_axis("left", "right")
	if input_x != 0:
		airdash_helper.last_input_x = sign(input_x)
	var target_speed := input_x * run_speed
	var current_accel := accel if is_on_floor() else air_accel

	if input_x != 0:
		velocity.x = move_toward(velocity.x, target_speed, current_accel * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	velocity.y += gravity * delta

	if (is_on_floor() or coyote_timer > 0 ) and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		coyote_timer = 0.0

# --------------------
# GRAPPLE LOGIC
# --------------------
func check_grapple_interrupt():
	if not is_grappling:
		return
	
	# Raycast from player to grapple point
	var from = global_position
	var to = rope_pivot if has_pivot else grapple_point
	
	grapple_ray.global_position = from
	grapple_ray.target_position = to - from
	grapple_ray.force_raycast_update()
	
	if grapple_ray.is_colliding():
		var hit = grapple_ray.get_collision_point()
		# If hit is **not the original grapple point**, disconnect
		if hit.distance_to(to) > 8:
			release_grapple()

func update_grapple(delta):
	match grapple_state:
		GrappleState.FIRING:
			update_firing(delta)
		GrappleState.LATCHED:
			apply_grapple_physics(delta)
		GrappleState.RETURNING:
			update_return(delta)
			
func update_firing(delta):
	var prev_pos = hook_position
	var step = hook_velocity * delta
	var next_pos = hook_position + step

	var max_vec = (next_pos - global_position)
	if max_vec.length() > max_grapple_distance:
		next_pos = global_position + max_vec.normalized() * max_grapple_distance

	hook_position = next_pos

	# Sweep ray (prev → current)
	grapple_ray.global_position = prev_pos
	grapple_ray.target_position = hook_position - prev_pos
	grapple_ray.force_raycast_update()

	# HIT
	if grapple_ray.is_colliding():
		var hit_point = grapple_ray.get_collision_point()

		# Final safety check
		
		if global_position.distance_to(hit_point) <= max_rope_length and can_grapple(hit_point):
			grapple_point = hit_point
			rope_length = global_position.distance_to(grapple_point)
			is_grappling = true
			grapple_state = GrappleState.LATCHED
			return

	# STOP at max range
	if hook_position.distance_to(global_position) >= max_grapple_distance:
		start_grapple_return()

func start_grapple_return():
	grapple_state = GrappleState.RETURNING
	is_grappling = false
	is_latched = false
func update_return(delta):
	var to_player = global_position - hook_position
	var dist = to_player.length()

	if dist < 16:
		grapple_state = GrappleState.IDLE
		rope.visible = false
		return

	hook_velocity = to_player.normalized() * hook_return_speed
	hook_position += hook_velocity * delta

func fire_grapple():
	rocket_boost_helper.rocket_boost_used = false
	grapple_state = GrappleState.FIRING

	hook_position = global_position
	var dir = (get_global_mouse_position() - global_position).normalized()
	hook_velocity = dir * hook_speed

	is_grappling = false
	is_latched = false

	rope.visible = true

func update_grapple_ray():
	var mouse_local := to_local(get_global_mouse_position())	
	var direction := mouse_local.normalized()

	# Always point the ray in the mouse direction, clamped to max distance
	grapple_ray.target_position = direction * max_grapple_distance

	# Force the ray to update its collision immediately
	grapple_ray.force_raycast_update()

	# Check if there's a valid collision
	if grapple_ray.is_colliding():
		var collision_point: Vector2 = grapple_ray.get_collision_point()
		var grapple_point_local := to_local(collision_point)
		var distance_to_collision := grapple_point_local.length()

		# Only draw the line if the collision is within max_grapple_distance
		if distance_to_collision <= max_rope_length and can_grapple(collision_point):
			# Store the valid grapple point for use elsewhere (optional)
			valid_grapple_point = grapple_point_local  # or global if preferred

			# Trigger a redraw to show the line to the collision point
			queue_redraw()  # Godot 4.x
			return

	# No valid grapple point – clear the drawing
	valid_grapple_point = null
	queue_redraw() # or queue_redraw()

func can_grapple(collision_point: Vector2):
	var collider = grapple_ray.get_collider()
	var mouse_local := to_local(get_global_mouse_position())
	var direction := mouse_local.normalized()
	if collider is TileMapLayer:
		# Need to offset the point in the direction the grapple ray is facing
		# otherwise it will not register the tile when aiming at the bottom
		# of a platform
		var offset_point := collision_point + direction * 0.01

		var local_point = collider.to_local(offset_point)
		var tile_coords = collider.local_to_map(local_point)
		var tile_data = collider.get_cell_tile_data(tile_coords)
		# Check Custom Data Layer "Grappleable" (must be defined in TileSet)
		
		if tile_data and tile_data.has_custom_data("Grappleable") and tile_data.get_custom_data("Grappleable"):
			return true
		else:
			return false
	else:
		return true


func apply_grapple_physics(delta):	
	check_grapple_interrupt()
	var to_hook := grapple_point - global_position
	var dist := to_hook.length()
	var dir := to_hook.normalized()
	# Tangent vector (perpendicular to rope)
	var tangent1 := Vector2(-dir.y, dir.x)
	var tangent2 := Vector2(dir.y, -dir.x)
	

	var tangent = tangent1 if velocity.dot(tangent1) > velocity.dot(tangent2) else tangent2

	# Apply rocket boost if active
	if rocket_boost_helper.rocket_boost_timer > 0 and not rocket_boost_helper.rocket_boost_used:
		var boost = tangent * rocket_boost_helper.rocket_boost_strength
		velocity += boost * delta
		rocket_boost_helper.rocket_boost_timer -= delta
		rocket_boost_helper.rocket_boost_used = true


	# --- LATCH ---
	if dist <= latch_distance:
		is_latched = true
		velocity = Vector2.ZERO
		camera.offset += velocity.normalized() * 6
		return
		
	if grapplePullUnlocked:
		if dist > max_rope_length:
			global_position = grapple_point - dir * max_rope_length
			
		velocity += dir * grapple_pull_strength * delta
		velocity *= grapple_damping
	else:
		global_position = grapple_point - dir * rope_length
		var radial_velocity = dir * velocity.dot(dir)
		var input_x := Input.get_axis("left", "right")
		velocity -= radial_velocity
		velocity.x += input_x * air_accel * delta * .35

		
		velocity.y += gravity * delta
		
		

func release_grapple():
	if grapple_state == GrappleState.LATCHED:
		start_grapple_return()


# --------------------
# CAMERA STUFF
# --------------------
func update_camera_pull(delta):
	# Ease back to center when not grappling
	if not is_grappling:
		camera.offset = camera.offset.lerp(
			Vector2.ZERO,
			delta * camera_pull_smoothing
		)
		return

	# Tangent-only camera pull (great for swinging)
	var to_hook = grapple_point - global_position
	var dir = to_hook.normalized()
	var tangent = Vector2(-dir.y, dir.x)

	var tangential_speed = velocity.dot(tangent)
	var pull = tangent * tangential_speed * camera_pull_strength
	pull = pull.limit_length(max_camera_offset)


	camera.offset = camera.offset.lerp(
		pull,
		delta * camera_pull_smoothing
	)
	
func update_rope_pivot():
	var from = global_position
	var to = grapple_point

	grapple_ray.global_position = from
	grapple_ray.target_position = to - from
	grapple_ray.force_raycast_update()

	if grapple_ray.is_colliding():
		var hit = grapple_ray.get_collision_point()

		# Ignore hit very close to hook
		if hit.distance_to(grapple_point) > 8:
			rope_pivot = hit
			has_pivot = true
			return

	has_pivot = false


# --------------------
# ROPE VISUAL
# --------------------
func update_rope():
	if grapple_state == GrappleState.IDLE:
		rope.visible = false
		return

	rope.visible = true

	var end_point := grapple_point if grapple_state == GrappleState.LATCHED else hook_position
	rope.points = [
		Vector2.ZERO,
		to_local(end_point)
	]

func update_aim_line():
	if grapple_state != GrappleState.IDLE:
		aim_line.visible = false
		return


	var mouse_local := to_local(get_global_mouse_position())
	var dir := mouse_local.normalized()
	var length = min(mouse_local.length(), max_grapple_distance)

	grapple_ray.target_position = dir * max_grapple_distance
	grapple_ray.force_raycast_update()

	var valid = grapple_ray.is_colliding() and mouse_local.length() <= max_rope_length

	aim_line.visible = true
	aim_line.points = [
		Vector2.ZERO,
		dir * length
	]

	aim_line.default_color = Color(
		0.4, 1.0, 0.6, 0.8
	) if valid else Color(
		1.0, 0.3, 0.3, 0.5
	)
