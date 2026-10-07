extends Node2D
## Root of the gameplay scene. Wires the pieces together; holds no game rules.

# TEMPORARY, until the shop and the run flow exist: the next wave starts by
# itself after this many seconds.
const _INTERMISSION: float = 3.0

var _intermission_timer: Timer

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _drop_spawner: DropSpawner = $DropSpawner
# Temporary, until the real HUD exists.
@onready var _debug_hud: Node = get_node_or_null("DebugHud")


func _ready() -> void:
	var bounds: Rect2i = _arena.get_bounds()
	_player.global_position = Vector2(bounds.get_center())
	_player.set_camera_limits(bounds)

	_intermission_timer = Timer.new()
	_intermission_timer.one_shot = true
	_intermission_timer.wait_time = _INTERMISSION
	_intermission_timer.timeout.connect(_on_intermission_over)
	add_child(_intermission_timer)

	RunState.start_run()
	_wave_spawner.setup(_player, bounds)
	_drop_spawner.setup(_player.collector)
	_wave_spawner.wave_ended.connect(_on_wave_ended)
	_wave_spawner.start_next_wave()
	if _debug_hud != null:
		_debug_hud.call(&"setup", _player, _wave_spawner)


func _on_wave_ended(_number: int) -> void:
	_intermission_timer.start()


func _on_intermission_over() -> void:
	if _player.health.is_alive():
		_wave_spawner.start_next_wave()
