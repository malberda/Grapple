extends Area2D

enum UpgradeType {
	GRAPPLE,
	ROCKETBOOST,
	AIRDASH,
	LATCHJUMP,
	SUPERGRAPPLE,
	DOUBLEJUMP,
	DOUBLEHOOK
}
@export var upgrade_type : UpgradeType

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if !body.is_in_group('player'):
		return
	else:
		print('upgrade')
		upgrade(body)
	pass # Replace with function body.

func upgrade(player):
	match upgrade_type:
		UpgradeType.GRAPPLE:
			player.grappleUnlocked = true
		UpgradeType.ROCKETBOOST:
			player.rocketBoostUnlocked = true
		UpgradeType.AIRDASH:
			player.airdashUnlocked = true
		UpgradeType.LATCHJUMP:
			player.latchJumpUnlocked = true
		UpgradeType.SUPERGRAPPLE:
			player.grapplePullUnlocked = true
		UpgradeType.DOUBLEJUMP:
			player.doubleJumpUnlocked = true
		UpgradeType.DOUBLEHOOK:
			player.doubleHookUnlocked = true
			
	queue_free()
