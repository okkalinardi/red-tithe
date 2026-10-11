extends Node2D
## Root of the gameplay scene. Wires the pieces together; holds no game rules.
##
## Between waves: wait for the drops to fly in, open the level-up screen if
## there are stat points to spend, then a short pause, then the next wave.

# TEMPORARY, until the shop and the run flow exist: the next wave starts by
# itself after this many seconds.
const _INTERMISSION: float = 3.0
# Room kept around a spawn point, in pixels: the largest enemy body radius
# plus a little.
const _SPAWN_CLEARANCE: float = 10.0
# The longest wait for the last drops to reach the player after a wave.
const _PICKUP_WAIT_LIMIT: float = 3.0
const _PICKUP_POLL: float = 0.1

var _intermission_timer: Timer
var _poll_timer: Timer

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _drop_spawner: DropSpawner = $DropSpawner
@onready var _hud: Hud = $Hud
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen


func _ready() -> void:
	var bounds: Rect2i = _arena.get_bounds()
	_player.global_position = Vector2(bounds.get_center())
	_player.set_camera_limits(bounds)

	# Child timers rather than SceneTree timers: they are freed with the
	# scene, so nothing resumes on a scene that is gone.
	_intermission_timer = _add_timer(_INTERMISSION)
	_intermission_timer.timeout.connect(_on_intermission_over)
	_poll_timer = _add_timer(_PICKUP_POLL)

	RunState.start_run()
	_wave_spawner.setup(_player, bounds, _arena.is_point_free.bind(_SPAWN_CLEARANCE))
	_drop_spawner.setup(_player.collector)
	_wave_spawner.wave_ended.connect(_on_wave_ended)
	_hud.setup(_player, _wave_spawner)
	_wave_spawner.start_next_wave()


func _on_wave_ended(_number: int) -> void:
	await _wait_for_pickups()
	if _player.health.is_alive() and _player.progression.stat_points > 0:
		_level_up_screen.open(_player)
		await _level_up_screen.closed
	_intermission_timer.start()


func _on_intermission_over() -> void:
	if _player.health.is_alive():
		_wave_spawner.start_next_wave()


func _wait_for_pickups() -> void:
	var waited: float = 0.0
	while not Pickup.active.is_empty() and waited < _PICKUP_WAIT_LIMIT:
		_poll_timer.start()
		await _poll_timer.timeout
		waited += _PICKUP_POLL


func _add_timer(seconds: float) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	add_child(timer)
	return timer
