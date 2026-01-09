extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play()
	$Timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	# For the first half of the timer
	if $Timer.time_left < $Timer.wait_time / 2:
		# Scale down the light
		$PointLight2D.texture_scale = $PointLight2D.texture_scale - 0.02
		$PointLight2D.energy = $PointLight2D.energy - 0.01
	else:
		# Scale up the light
		$PointLight2D.texture_scale = $PointLight2D.texture_scale + 0.02
		$PointLight2D.energy = $PointLight2D.energy + 0.01
	pass
