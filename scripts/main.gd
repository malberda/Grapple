extends Node2D

@onready var player: CharacterBody2D = $Player
@export var grappleUnlocked = false
@export var grapplePullUnlocked = false
@export var rocketBoostUnlocked = false
@export var airdashUnlocked = false
@export var doubleJumpUnlocked = false
@export var doubleHookUnlocked = false
@export var latchJumpUnlocked = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.grappleUnlocked = grappleUnlocked
	player.grapplePullUnlocked = grapplePullUnlocked
	player.grapplePullUnlocked = grapplePullUnlocked
	player.airdashUnlocked = airdashUnlocked
	player.doubleJumpUnlocked = doubleJumpUnlocked
	player.doubleHookUnlocked = doubleHookUnlocked
	player.latchJumpUnlocked = latchJumpUnlocked
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
