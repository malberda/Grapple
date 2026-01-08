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
# MOVEMENT 
# --------------------
@export var run_speed := 240.0
@export var accel := 2000.0
@export var air_accel := 1200.0
@export var friction := 1800.0
@export var gravity := 1500.0
@export var jump_velocity := -420.0
@export var jump_cut_multiplier := 0.35


# --------------------
# GRAPPLE
# --------------------
@export var grapple_pull_strength := 3200.0
@export var grapple_damping := 0.99
@export var max_grapple_distance := 900.0
@export var latch_distance := 40
@export var max_rope_length := 400.0
var coyote_time = .1  #coyote timing for jump


# --------------------
# GENERAL USE
# --------------------
var is_latched := false
var is_grappling := false
var grapple_point: Vector2
var grapple_requested := false
var coyote_timer = 0.0


@onready var grapple_ray := $GrappleRay
@onready var rope := $Line2D

func _ready():
	floor_max_angle = deg_to_rad(50)

# --------------------
# INPUT
# --------------------
func _input(event):
	if event.is_action_released('jump') and velocity.y < 0:
		velocity.y *= jump_cut_multiplier
	
	if event.is_action_pressed("grapple"):
		grapple_requested = true
		
	if event.is_action_pressed("reset_level"):
		get_tree().reload_current_scene()

	if event.is_action_released("grapple"):
		release_grapple()
		grapple_requested = false

# --------------------
# PHYSICS LOOP
# --------------------
func _physics_process(delta):
	update_grapple_ray()
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if grapple_requested and not is_grappling:
		try_start_grapple()
		grapple_requested = false

	if is_latched:
		velocity = Vector2.ZERO  # stick to wall
		if Input.is_action_just_pressed("jump"):
			release_grapple()
			velocity.y = jump_velocity
	elif is_grappling:
		apply_grapple_physics(delta)
	else:
		apply_movement(delta)

	move_and_slide()
	update_rope()

# --------------------
# NORMAL MOVEMENT
# --------------------
func apply_movement(delta):
	var input_x := Input.get_axis("left", "right")

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
func update_grapple_ray():
	var mouse_local := to_local(get_global_mouse_position())
	grapple_ray.target_position = mouse_local.normalized() * max_grapple_distance

func try_start_grapple():
	grapple_ray.force_raycast_update()

	if not grapple_ray.is_colliding():
		return
		
	var point = grapple_ray.get_collision_point()
	
	if global_position.distance_to(point) > max_rope_length:
		return

	grapple_point = grapple_ray.get_collision_point()
	is_grappling = true

func apply_grapple_physics(delta):
	var to_hook := grapple_point - global_position
	var dist := to_hook.length()

	if dist <= latch_distance:
		is_latched = true
		velocity = Vector2.ZERO
		return
		
	var dir : Vector2 = to_hook.normalized()
	
	if dist > max_rope_length:
		global_position = grapple_point - dir * max_rope_length
		
	velocity += dir * grapple_pull_strength * delta
	velocity *= grapple_damping

func release_grapple():
	is_grappling = false
	is_latched = false


# --------------------
# ROPE VISUAL
# --------------------
func update_rope():
	if is_grappling:
		rope.visible = true
		rope.points = [Vector2.ZERO, to_local(grapple_point)]
	else:
		rope.visible = false
