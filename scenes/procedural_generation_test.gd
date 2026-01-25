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
var hallway_blocks = []
var room_blocks = []
var end_blocks = []

# Stores all the open connections when
# the depth limit is hit so they can be filled in at the end
var end_connections = []


const MAX_DEPTH = 30
var use_seed = false
const SEED = 4234

# Block info cache: PackedScene -> { "dirs": Array[String], "dir_to_pos": Dict[String, Vector2], "conn_count": int }
var block_info: Dictionary = {}

func _ready() -> void:
	if use_seed:
		seed(SEED)
	
	if not level_block_start:
		push_error("level_block_start is not set!")
		return
	
	# Start with entrance piece
	var start_block = level_block_start.instantiate()
	add_child(start_block)
	#erase_under_block($Terrain, start_block)
	placed_blocks.append(start_block)
	
	# Load all available level block scenes
	hallway_blocks = build_scene_map("res://scenes/level_blocks/hallways/")
	room_blocks = build_scene_map("res://scenes/level_blocks/rooms/")
	end_blocks = build_scene_map("res://scenes/level_blocks/ends/")
	
	
	get_global_polygon_points(hallway_blocks[9].instantiate())
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
	fill_in_open_connections()
	
	save_scene_to_editor(self)

func add_next_connections(connection_nodes: Array, depth: int, max_depth: int):
	if connection_nodes.is_empty():
		return;
		
	if depth == max_depth:
		end_connections.append_array(connection_nodes)
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
				add_child(new_block)
				placed_blocks.append(new_block)
				#erase_under_block($Terrain, new_block)
				block_placed = true
				break
			else:
				new_block.queue_free()
		
		# If couldn't find a block to place or at max depth
		if !block_placed:
			end_connections.append(connection)
			continue
		
		for c in new_block.get_connection_nodes():
			if c.direction != needed_direction:
				# Add new open connections (except the one we just connected)
				next_connections.append(c)
				
	add_next_connections(next_connections, depth + 1, max_depth)

func fill_in_open_connections():
	for c in end_connections:
		var needed_dir = get_opposite_direction(c.direction)
		for b in end_blocks:
			if needed_dir in block_info[b]["dirs"]:
				var new_block = b.instantiate()
				# Calculate position so the connecting points match
				var local_pos = block_info[b]["dir_to_pos"][needed_dir]
				var offset = c.position - local_pos
				new_block.position = offset
				add_child(new_block)
				break

func get_opposite_direction(dir: String) -> String:
	match dir:
		"top": return "bottom"
		"bottom": return "top"
		"left": return "right"
		"right": return "left"
	return ""

func has_overlap(new_block: Node2D) -> bool:
	var new_rect = new_block.get_rect_global()
	if new_rect == Rect2(): return false # no bounds → allow placement or handle differently
	for existing in placed_blocks:
		if existing == new_block:
			continue
		var ex_rect = existing.get_rect_global()
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
		local_points.append(Vector2( half_size.x,  half_size.y))
		local_points.append(Vector2(-half_size.x,  half_size.y))
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
	
func erase_tiles_inside_polygon(tilemap_layer: TileMapLayer, polygon_global: PackedVector2Array) -> void:
	if polygon_global.size() < 3:
		push_warning("Polygon must have at least 3 points")
		return
	
	# Compute global AABB of the polygon for efficient iteration bounds
	var min_p := Vector2(+INF, +INF)
	var max_p := Vector2(-INF, -INF)
	for p: Vector2 in polygon_global:
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)
	
	var bounds_rect_global := Rect2(min_p, max_p - min_p)
	
	# Expand bounds to ensure edge tiles are checked
	var tile_size := tilemap_layer.tile_set.tile_size
	var expand = max(tile_size.x, tile_size.y) * 0.6  # ~half diagonal for safety
	bounds_rect_global = bounds_rect_global.expand(Vector2(expand, expand))
	
	# Convert bounds to map coordinates
	var local_tl := tilemap_layer.to_local(bounds_rect_global.position)
	var local_br := tilemap_layer.to_local(bounds_rect_global.end)
	var map_tl := tilemap_layer.local_to_map(local_tl)
	var map_br := tilemap_layer.local_to_map(local_br)
	
	# Iterate over candidate cells
	for x in range(map_tl.x, map_br.x + 1):
		for y in range(map_tl.y, map_br.y + 1):
			var coords := Vector2i(x, y)
			var center_local := tilemap_layer.map_to_local(coords)
			var center_global := tilemap_layer.to_global(center_local)
			
			if Geometry2D.is_point_in_polygon(center_global, polygon_global):
				tilemap_layer.erase_cell(coords)


func erase_under_block(tilemap_layer: TileMapLayer, block: Node2D) -> void:
	var polygon := get_global_polygon_points(block)
	erase_tiles_inside_polygon(tilemap_layer, polygon)
