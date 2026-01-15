extends Node2D

var connection_nodes: Array[ConnectionNode] = []
class ConnectionNode:
	var position: Vector2       # world position of connection
	var direction: String       # "top", "bottom", "left", "right"
	var parent_block: Node2D    # block this connection belongs to
	
	func _init(pos: Vector2, dir: String, parent: Node2D):
		position = pos
		direction = dir
		parent_block = parent
	

func get_connection_nodes() -> Array[ConnectionNode]:
	var connection_nodes: Array[ConnectionNode] = []
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
		
	
## Optional - for better collision checking
func get_rect() -> Rect2:
	# return approximate bounding rect in local space
	return $Area2D/CollisionShape2D.shape.get_rect()

func get_relative_side(point: Vector2, rect: Rect2) -> String:
	if rect.has_point(point):
		print("ERRROR !!! Level block connection point is not on rect border")
	
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
	
	return "on_edge"
