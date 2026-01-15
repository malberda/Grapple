extends Node2D

# Constants
var tilesheet_dimensions = 256 # should match tilesheet square size, e.g. 256x256px
var level_block_size = 16 # matches the level block square size, 16x16
var level_block_offset = tilesheet_dimensions * level_block_size # the offset used for coords for the level block
var map_size_y = 10
var map_size_x = 10

# The scene the player always starts in
var level_block_start = preload("res://scenes/level_blocks/_start_block.tscn")

var placed_blocks = []

var intermediate_blocks = []
var end_blocks = []

const MAX_DEPTH = 3

var use_seed = false
const SEED = 4234

# Simple struct-like class for connection info (you can also use Dictionary)
class ConnectionNode:
	var position: Vector2       # world position of connection
	var direction: String       # "top", "bottom", "left", "right"
	var parent_block: Node2D    # block this connection belongs to
	
	func _init(pos: Vector2, dir: String, parent: Node2D):
		position = pos
		direction = dir
		parent_block = parent

func _ready() -> void:
	if use_seed:
		seed(SEED)
	
	if not level_block_start:
		push_error("level_block_start is not set!")
		return
	
	# Start with entrance piece
	var start_block = level_block_start.instantiate()
	add_child(start_block)
	placed_blocks.append(start_block)
		
	# Load all available level block scenes
	var level_block_map = build_scene_map("res://scenes/level_blocks/")
	
	for l in level_block_map:
		var y = l.instantiate()
		if y.get_connection_nodes().size() != 1:
			intermediate_blocks.append(l)
		y.queue_free()
			
	for l in level_block_map:
		var y = l.instantiate()
		if y.get_connection_nodes().size() == 1:
			end_blocks.append(l)
		y.queue_free()
	
	for c in start_block.get_connection_nodes():
		add_next_connections(c, 1, MAX_DEPTH)	
	
	save_scene_to_editor(self)


func add_next_connections(connection, depth: int, max_depth: int):
	var blocks = []
	if depth == max_depth:
		blocks = end_blocks
	else:
		blocks = intermediate_blocks
	
			# Get opposite direction we need to match
	var needed_direction = get_opposite_direction(connection.direction)
	
	# Find suitable blocks that have a connection in the required direction
	var candidates = []
	for block_scene in blocks:
		var block = block_scene.instantiate()
		if block.has_connection_in_direction(needed_direction):
			candidates.append(block_scene)
		block.queue_free()  # cleanup test instance
	
	if candidates.is_empty():
		print("No matching block found for direction: ", needed_direction)
		return
		
	
		
	# Find a compatible block that doesn't collide with any existing blocks
	var new_block = null
	var block_placed = false
	for c in range(candidates.size()):
		new_block = candidates.pick_random().instantiate()
		
		# Calculate position so the connecting points match
		var offset = calculate_connection_offset(
			connection.position,
			new_block,
			needed_direction
		)
	
		new_block.position = offset
		if !has_overlap(new_block):
			block_placed = true
			add_child(new_block)
			placed_blocks.append(new_block)
			break
	
	# If couldn't find a block to place or at max depth
	if !block_placed or depth == max_depth:
		# End recursion
		return;
	
	# Add new open connections (except the one we just connected)
	var next_connections = new_block.get_connection_nodes()
	for next_connection in next_connections:
		# Don't use the connection made to the current connection
		# for the next recursion step
		if next_connection.position != connection.position:
			add_next_connections(next_connection, depth + 1, max_depth)

func get_opposite_direction(dir: String) -> String:
	match dir:
		"top":    return "bottom"
		"bottom": return "top"
		"left":   return "right"
		"right":  return "left"
	return ""

func get_global_bounds_rect(block: Node2D) -> Rect2:
	var bounds_area = block.get_node_or_null("Area2D") as Area2D
	if not bounds_area:
		return Rect2()  # or push warning
	
	var shape = bounds_area.get_node("CollisionShape2D") as CollisionShape2D
	if not shape or not shape.shape is RectangleShape2D:
		return Rect2()
		
	var rect_shape = shape.shape as RectangleShape2D
	var half_extents = rect_shape.extents
	
	# Local → global transformation
	var top_left_local  = Vector2(-half_extents.x, -half_extents.y)
	var bottom_right_local = Vector2(half_extents.x, half_extents.y)
	
	var top_left_global  = block.to_global(top_left_local)
	var bottom_right_global = block.to_global(bottom_right_local)
	
	return Rect2(top_left_global, bottom_right_global - top_left_global)

func has_overlap(new_block: Node2D) -> bool:
	var new_rect = get_global_bounds_rect(new_block)
	if new_rect == Rect2(): return false  # no bounds → allow placement or handle differently
	
	for existing in placed_blocks:
		if existing == new_block: continue
		var ex_rect = get_global_bounds_rect(existing)
		if new_rect.intersects(ex_rect):
			return true
	return false

func calculate_connection_offset(
	target_pos: Vector2,
	new_block: Node2D,
	target_direction: String
) -> Vector2:
	var new_block_connection = new_block.get_connection_in_direction(target_direction)
	if not new_block_connection:
		push_error("Block has no connection in direction: " + target_direction)
		return target_pos
	
	# We want the new block's connection point to land exactly on target_pos
	var local_to_new_connection = new_block_connection.position
	var world_pos_of_new_connection = target_pos
	
	# Calculate where the pivot/origin of the new block should be
	return world_pos_of_new_connection - local_to_new_connection


# Helper: returns Array[PackedScene]
func build_scene_map(path: String) -> Array:
	var scenes: Array[PackedScene] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "" and file_name[0] != "_":
			if !dir.current_is_dir() and file_name.ends_with(".tscn"):
				var full_path = path.path_join(file_name)
				var scene = load(full_path) as PackedScene
				if scene:
					scenes.append(scene)
			file_name = dir.get_next()
	return scenes

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func validate_block_map(block_map: Dictionary):
	for key in block_map:
		var block_map_item = block_map[key]
		assert(block_map_item.has_meta("Can Be Floor"), "Block map item missing required 'Can Be Floor' metadata")
		assert(block_map_item.has_meta("Congruency"), "Block map item missing required 'Congruency' metadata")

#func build_scene_map(folder_path: String) -> Dictionary:
	#var scene_map: Dictionary = {}  # { "rooms": { "001": { "north": scene, ... } }, "enemies": { ... } }
	#
	#var dir = DirAccess.open(folder_path)
	#if not dir: return scene_map
	#
	#var files = dir.get_files()
	#for file in files:
		#if not (file.ends_with(".tscn") or file.ends_with(".scn")): continue
		#
		#var base_name = file.get_basename()
		#var parts = base_name.split("_")  # ["room", "001", "north"]
		#
		#if parts.size() >= 2:
			#var type_key = parts[0]  # "room", "enemy"
			#var id = parts[1]        # "001"
			#
			#scene_map.get_or_add(type_key, {}).get_or_add(id, {})  # Create nested dicts
			#
			#var full_path = folder_path + base_name + ".tscn"
			#if ResourceLoader.exists(full_path):
				#var scene = ResourceLoader.load(full_path) as PackedScene
				#if scene:
					## Store direction if present, or just the scene
					#if parts.size() > 2:
						#var direction = parts[2]
						#scene_map[type_key][id][direction] = scene
					#else:
						#scene_map[type_key][id] = scene  # No direction
	#
	#return scene_map


func set_owner_recursive(node, root):
	if node != root:
		node.owner = root
	for child in node.get_children():
		set_owner_recursive(child, root)

func save_scene_to_editor(node_to_save: Node, file_path: String = "res://saved_runtime_scene.tscn"):
	# 1. Ensure all children are owned by the root node
	set_owner_recursive(node_to_save, node_to_save)
	
	# 2. Create a new PackedScene and pack the node
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(node_to_save)
	
	if result == OK:
		# 3. Save the PackedScene to a .tscn file
		var error = ResourceSaver.save(packed_scene, file_path)
		if error == OK:
			print("Scene saved successfully to: ", file_path)
		else:
			push_error("Failed to save scene: ", error)
	else:
		push_error("Failed to pack scene: ", result)
