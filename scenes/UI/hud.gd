extends CanvasLayer

@export var save_scene_button: Button

func _ready() -> void:
	save_scene_button = $SaveSceneButton

func bind_save_scene_button(callback: Callable):
	save_scene_button.connect("pressed", callback)
