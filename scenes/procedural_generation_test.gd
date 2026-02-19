extends Node2D

var level_block_start = preload("res://scenes/level_blocks/_start_block.tscn")
var player_scene = preload("res://scenes/player_characters/buffman.tscn")
var connection_node_scene = preload("res://scenes/level_blocks/_connection_node.tscn")

var placed_blocks = []
var hallway_blocks = []
var room_blocks = []
var end_blocks = []

# Stores all the open connections when
# the depth limit is hit so they can be filled in at the end
var end_connections = []

const MAX_DEPTH = 2
var use_seed = false
const SEED = 4234

# Block info cache: PackedScene -> { "dirs": Array[String], "dir_to_pos": Dict[String, Vector2], "conn_count": int }
var block_info: Dictionary = {}

@onready var main_tilemap: TileMapLayer = $Terrain

@onready var background_scene = preload("res://scenes/background.tscn")

func _ready() -> void:
	if use_seed:
		seed(SEED)
	if not level_block_start:
		push_error("level_block_start is not set!")
		return
	
	# Start with entrance piece
	var start_block = level_block_start.instantiate()
	placed_blocks.append(start_block)
	copy_tiles_from_block(start_block)
	var start_block_open_area = start_block.get_node("Area2D").duplicate()
	add_child(start_block_open_area)
	
	var player = player_scene.instantiate()
	add_child(player)
	player.global_position = start_block.global_position
	
	# Load all available level block scenes
	hallway_blocks = build_scene_map("res://scenes/level_blocks/hallways/")
	room_blocks = build_scene_map("res://scenes/level_blocks/rooms/")
	end_blocks = build_scene_map("res://scenes/level_blocks/ends/")
	
	# Cache metadata about all blocks
	var all_blocks = []
	all_blocks.append_array(room_blocks)
	all_blocks.append_array(hallway_blocks)
	all_blocks.append_array(end_blocks)
	for l in all_blocks:
		var y = l.instantiate()
		var conns = y.get_connection_nodes()
		var conn_count = conns.size()
		block_info[l] = { "dirs": [], "dir_to_pos": {}, "conn_count": conn_count, "name": y.name }
		for c in conns:
			block_info[l]["dirs"].append(c.direction)
			block_info[l]["dir_to_pos"][c.direction] = c.position # local position
		y.queue_free()
	
	add_next_connections(start_block.get_connection_nodes(), 1, MAX_DEPTH)
	player.bind_new_block_spawn_area_collision(func(node): 
		handle_player_open_connection_collision(node)
	)	
	$HUD.bind_save_scene_button(func(): save_scene_to_editor(self))

func handle_player_open_connection_collision(node):
	node.queue_free()
	var connection_data = end_connections[node.get_parent().connection_id]
	add_next_connections([connection_data], connection_data.depth, connection_data.depth + 2)
	

func add_next_connections(connection_nodes: Array, depth: int, max_depth: int):
	if connection_nodes.is_empty():
		return;
	if depth == max_depth:
		for n in connection_nodes:
			# Store the depth of the node
			n.depth = depth
			# Add a connection node to this scene so when
			# the player collides with it we can generate more blocks
			var connection_node = connection_node_scene.instantiate()
			add_child(connection_node)
			connection_node.global_position = n.position
			connection_node.connection_id = end_connections.size()
			end_connections.append(n)
		return
	
	var blocks = room_blocks
	if ![3, 6, 9, 12, 15, 17, 19].has(depth):
		blocks = hallway_blocks
	
	var next_connections = []
	for connection in connection_nodes:
		# Get opposite direction we need to match
		var needed_direction = get_opposite_direction(connection.direction)
		
		# Find suitable blocks that have a connection in the required direction
		var candidates = []
		for block_scene in blocks:
			if needed_direction in block_info[block_scene]["dirs"]:
				candidates.append(block_scene)
		
		if candidates.is_empty():
			print("No matching block found for direction: ", needed_direction)
			return
		
		# Shuffle for random selection without replacement
		candidates.shuffle()
		
		# Find a compatible block that doesn't collide with any existing blocks
		var new_block = null
		var block_placed = false
		for cand in candidates:
			new_block = cand.instantiate()
			
			# Calculate position so the connecting points match
			var local_pos = block_info[cand]["dir_to_pos"][needed_direction]
			var offset = connection.position - local_pos
			new_block.position = offset
			
			if !has_overlap(new_block):
				placed_blocks.append(new_block)
				copy_tiles_from_block(new_block)
				var block_open_area = new_block.get_node("Area2D").duplicate()
				block_open_area.name = new_block.name + " " + str(randi())
				add_child(block_open_area)
				block_open_area.global_position = offset
				block_placed = true
				
				#var connection_scenes: Array[Node] = new_block.get_node("Connections").get_children()
				#for c in connection_scenes:
					#var c_copy: Node2D = c.duplicate()
					#c_copy.name = c.name + " " + str(randi())
					#add_child(c_copy)
					#c_copy.global_position = c_copy.position + offset
				break
			else:
				new_block.queue_free()
		
		# If couldn't find a block to place or at max depth
		if !block_placed:
			connection.depth = depth
			fill_in_open_connection(connection)
			continue
		
		for c in new_block.get_connection_nodes():
			if c.direction != needed_direction:
				# Add new open connections (except the one we just connected)
				next_connections.append(c)
	
	add_next_connections(next_connections, depth + 1, max_depth)

func fill_in_open_connections():
	for c in end_connections:
		fill_in_open_connection(c)
		
# c is a ConnectionNode defined in block.gd
func fill_in_open_connection(c):
	var needed_dir = get_opposite_direction(c.direction)
	for b in end_blocks:
		if needed_dir in block_info[b]["dirs"]:
			var new_block = b.instantiate()
			
			# Calculate position so the connecting points match
			var local_pos = block_info[b]["dir_to_pos"][needed_dir]
			var offset = c.position - local_pos
			new_block.position = offset
			
			placed_blocks.append(new_block)
			copy_tiles_from_block(new_block)
			break

func get_opposite_direction(dir: String) -> String:
	match dir:
		"top": return "bottom"
		"bottom": return "top"
		"left": return "right"
		"right": return "left"
	return ""

func has_overlap(new_block: Node2D) -> bool:
	var new_rect = get_rect_global(new_block)
	if new_rect == Rect2(): return false # no bounds → allow placement or handle differently
	for existing in placed_blocks:
		if existing == new_block:
			continue
		var ex_rect = get_rect_global(existing)
		if new_rect.intersects(ex_rect):
			return true
	return false

# Helper: returns Array[PackedScene]
func build_scene_map(path: String) -> Array:
	var scenes: Array[PackedScene] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".tscn") and file_name[0] != "_":
				var full_path = path.path_join(file_name)
				var scene = load(full_path) as PackedScene
				if scene:
					scenes.append(scene)
			file_name = dir.get_next()
	return scenes

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

func get_global_polygon_points(block: Node2D) -> PackedVector2Array:
	var bounds_area = block.get_node_or_null("Area2D") as Area2D
	if not bounds_area:
		push_warning("No Area2D found in block")
		return PackedVector2Array()
	
	var collision_shape = bounds_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		push_warning("No CollisionShape2D found in Area2D")
		return PackedVector2Array()
	
	var shape_resource = collision_shape.shape
	if not shape_resource:
		return PackedVector2Array()
	
	var local_points: PackedVector2Array = []
	if shape_resource is RectangleShape2D:
		var half_size = shape_resource.size / 2.0
		local_points.append(Vector2(-half_size.x, -half_size.y))
		local_points.append(Vector2( half_size.x, -half_size.y))
		local_points.append(Vector2( half_size.x, half_size.y))
		local_points.append(Vector2(-half_size.x, half_size.y))
	elif shape_resource is ConvexPolygonShape2D:
		local_points = shape_resource.points
		if local_points.is_empty():
			push_warning("ConvexPolygonShape2D has no points")
			return PackedVector2Array()
	else:
		push_warning("Unsupported shape type: " + shape_resource.get_class())
		return PackedVector2Array()
	
	var global_points: PackedVector2Array = PackedVector2Array()
	for i in local_points.size():
		global_points.append(collision_shape.to_global(local_points[i]))
	return global_points

func get_rect_global(block: Node2D) -> Rect2:
	var poly = get_global_polygon_points(block)
	if poly.size() == 0:
		return Rect2()
	var min_v = Vector2(INF, INF)
	var max_v = Vector2(-INF, -INF)
	for p in poly:
		min_v.x = min(min_v.x, p.x)
		min_v.y = min(min_v.y, p.y)
		max_v.x = max(max_v.x, p.x)
		max_v.y = max(max_v.y, p.y)
	return Rect2(min_v, max_v - min_v)

func copy_tiles_from_block(block: Node2D) -> void:
	var block_tilemap = block.get_node("Terrain") as TileMapLayer  # Adjust node path if different
	if not block_tilemap:
		push_warning("No TileMapLayer found in block")
		return

	var tile_size = Vector2(main_tilemap.tile_set.tile_size) if main_tilemap.tile_set else Vector2(16, 16)
	var offset_map: Vector2i = (block.global_position / tile_size).floor()

	var coords: Array[Vector2i] = []
	for source_coord: Vector2i in block_tilemap.get_used_cells():
		var source_id = block_tilemap.get_cell_source_id(source_coord)
		if source_id == -1:
			continue

		var target_coord = source_coord + offset_map
		coords.append(target_coord)

		main_tilemap.set_cell(target_coord, source_id,
			block_tilemap.get_cell_atlas_coords(source_coord),
			block_tilemap.get_cell_alternative_tile(source_coord)
		)

	if coords.is_empty():
		return

	var min_x: int = coords[0].x
	var max_x: int = coords[0].x
	var min_y: int = coords[0].y
	var max_y: int = coords[0].y

	for coord in coords:
		min_x = min(min_x, coord.x)
		max_x = max(max_x, coord.x)
		min_y = min(min_y, coord.y)
		max_y = max(max_y, coord.y)

	var border_coords: Array[Vector2i] = []
	for coord in coords:
		if coord.x == min_x or coord.x == max_x or coord.y == min_y or coord.y == max_y:
			border_coords.append(coord)

	apply_terrain(border_coords)

func apply_terrain(coords: Array[Vector2i]):
	main_tilemap.set_cells_terrain_connect(  # Auto-applies rules!
		coords,  # cells to fill
		0,  # terrain_set
		1,  # terrain (e.g., "Cave")
		false  # ignore_empty_terrains
	)
