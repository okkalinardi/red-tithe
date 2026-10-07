extends Node2D
## Root of the gameplay scene. Wires the pieces together; holds no game rules.

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player


func _ready() -> void:
	var bounds: Rect2i = _arena.get_bounds()
	_player.global_position = Vector2(bounds.get_center())
	_player.set_camera_limits(bounds)
