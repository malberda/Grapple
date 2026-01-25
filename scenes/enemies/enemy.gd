extends Node2D

@export var starting_health = 100.0
var health = starting_health
@onready var init_health_bar_width = $HealthBar.size.x

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func take_damage(damage_amount: int):
	if health - damage_amount == 0:
		health = 0
		self.queue_free()
	else:
		self.health -= damage_amount
		
	update_health_bar()
	
func update_health_bar():
	$HealthBar.size.x = init_health_bar_width * (health / starting_health)
