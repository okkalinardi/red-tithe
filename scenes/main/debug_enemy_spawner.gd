extends Node
## TEMPORARY. Drips enemies into the arena so combat can be tried before the
## wave spawner exists. Delete this node and this file when the wave spawner
## task is done.

@export var enemy_data: EnemyData
## Seconds between batches.
@export var interval: float = 1.5
@export var batch_size: int = 3
## No more are spawned while this many are alive.
@export var max_alive: int = 30
## Distance from the player at which enemies appear, in pixels.
@export var spawn_distance: float = 180.0
## Keeps spawns this far inside the arena walls.
@export var wall_margin: float = 12.0

var _player: Node2D
var _bounds: Rect2
var _time_left: float = 0.0


func setup(player: Node2D, bounds: Rect2i) -> void:
	_player = player
	_bounds = Rect2(bounds).grow(-wall_margin)


func _physics_process(delta: float) -> void:
	if enemy_data == null or _player == null:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = interval
	for i: int in batch_size:
		if Enemy.active.size() >= max_alive:
			return
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * spawn_distance
		var at: Vector2 = (_player.global_position + offset).clamp(_bounds.position, _bounds.end)
		Enemy.spawn(enemy_data, at, _player)
