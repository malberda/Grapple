extends Node2D

var connection_nodes: Array[ConnectionNode] = []
class ConnectionNode:
	var position: Vector2       # world position of connection
	var direction: String       # "top", "bottom", "left", "right"
	var parent_block: Node2D    # block this connection belongs to
	var depth: int
	
	func _init(pos: Vector2, dir: String, parent: Node2D):
		position = pos
		direction = dir
		parent_block = parent
			

func get_connection_nodes() -> Array[ConnectionNode]:
	if connection_nodes.size() > 0:
		return connection_nodes
	
	var nodes = $Connections.get_children()
	for n in nodes:
		var cn = ConnectionNode.new(
			to_global(n.position),
			get_node_direction(n),
			self
		)
		connection_nodes.append(cn)
	return connection_nodes
	
	
func get_connection_in_direction(dir: String) -> Variant:
	for n in get_connection_nodes():
		if n.direction == dir:
			return n
	
	return null

func has_connection_in_direction(dir: String) -> bool:
	return get_connection_in_direction(dir) != null

func get_node_direction(n: Node2D) -> String:
	return get_relative_side(n.position, self.get_rect())
		
	
func get_rect() -> Rect2:
	# Return approximate bounding rect in local space
	var shape = $Area2D/CollisionShape2D.shape
	if shape is RectangleShape2D:
		return shape.get_rect()
	
	var points: Array = shape.points
	if points.is_empty():
		return Rect2()
	
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	
	for p: Vector2 in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	
func get_rect_global():
	return self.global_transform * self.get_rect()

func get_relative_side(point: Vector2, rect: Rect2) -> String:
	var left = rect.position.x
	var right = rect.end.x
	var top = rect.position.y
	var bottom = rect.end.y
	
	# Prioritize horizontal (left/right) for diagonals
	if point.x == left:
		return "left"
	elif point.x == right:
		return "right"
	elif point.y == top:
		return "top"
	elif point.y == bottom:
		return "bottom"
	
	print("block.gd: ERRROR !!! Level block connection point is not on rect border:", self.name)
	return "not_on_edge"
