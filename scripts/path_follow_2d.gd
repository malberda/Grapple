# Script on PathFollow2D (GDScript)
extends PathFollow2D

@export var speed: float = 100.0  # Pixels per second

func _ready():
	self.rotates = false
	
func _on_snake_spotted():
	set_process(false)
	
func _process(delta: float) -> void:
	progress += speed * delta  # Moves forward; use -= for backward
