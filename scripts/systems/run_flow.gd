class_name RunFlow
extends Node
## The run, start to finish: playing a wave, the break between waves, death
## or victory, the game-over panel and restart.
##
## [codeblock]
## PLAYING --wave ends--> BETWEEN_WAVES --break over--> PLAYING
##    |                        |
##    |                        +--last wave was the final one--> VICTORY
##    +--player dies--> DEAD
## DEAD / VICTORY --restart--> the scene is reloaded, a new run starts
## [/codeblock]
## The break between waves: wait for the last drops to reach the player,
## open the level-up screen if there are stat or skill points to spend, then a short
## pause before the next wave.

signal phase_changed(phase: Phase)

enum Phase { STARTING, PLAYING, BETWEEN_WAVES, DEAD, VICTORY }

## Seconds of calm after the level-up screen, before the next wave.
@export var intermission: float = 3.0
## The longest wait for the last drops to reach the player after a wave.
@export var pickup_wait_limit: float = 3.0
## Seconds between the player's death and the game-over panel, so the death
## can be seen.
@export var game_over_delay: float = 1.5

const _PICKUP_POLL: float = 0.1

var phase: Phase = Phase.STARTING

var _player: Player
var _spawner: WaveSpawner
var _level_up_screen: LevelUpScreen
var _game_over_panel: GameOverPanel
var _timer: Timer


func _ready() -> void:
	# A child timer rather than a SceneTree timer: it is freed with the scene,
	# so nothing resumes on a scene that is gone.
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)


func setup(player: Player, spawner: WaveSpawner, level_up_screen: LevelUpScreen, game_over_panel: GameOverPanel) -> void:
	_player = player
	_spawner = spawner
	_level_up_screen = level_up_screen
	_game_over_panel = game_over_panel
	spawner.wave_ended.connect(_on_wave_ended)
	Events.player_died.connect(_on_player_died)
	game_over_panel.restart_requested.connect(restart)


## Resets the run's records and starts wave 1.
func start_run() -> void:
	RunState.start_run()
	_set_phase(Phase.PLAYING)
	_spawner.start_next_wave()


## Throws the whole run away and starts a new one: the scene is reloaded, so
## every node is new, and the shared lists and pools are emptied.
func restart() -> void:
	get_tree().paused = false
	Enemy.active.clear()
	Pickup.active.clear()
	Projectile.active.clear()
	Pools.clear()
	get_tree().reload_current_scene()


func _set_phase(new_phase: Phase) -> void:
	if new_phase == phase:
		return
	phase = new_phase
	phase_changed.emit(phase)


func _on_wave_ended(number: int) -> void:
	if phase != Phase.PLAYING:
		return
	_set_phase(Phase.BETWEEN_WAVES)
	await _wait_for_pickups()
	if phase != Phase.BETWEEN_WAVES:
		return
	if number >= _spawner.get_wave_count():
		_finish(true)
		return
	if LevelUpScreen.has_points_to_spend(_player):
		_level_up_screen.open(_player)
		await _level_up_screen.closed
	await _wait(intermission)
	if phase != Phase.BETWEEN_WAVES:
		return
	_set_phase(Phase.PLAYING)
	_spawner.start_next_wave()


func _on_player_died() -> void:
	if phase == Phase.DEAD or phase == Phase.VICTORY:
		return
	_set_phase(Phase.DEAD)
	_finish(false)


func _finish(victory: bool) -> void:
	if victory:
		_set_phase(Phase.VICTORY)
	RunState.end_run()
	Events.run_ended.emit(victory)
	if not victory:
		await _wait(game_over_delay)
	_game_over_panel.show_result(
		victory,
		RunState.wave,
		_spawner.get_wave_count(),
		RunState.elapsed_time,
		RunState.kills,
		_player.progression.level,
	)
	get_tree().paused = true


func _wait_for_pickups() -> void:
	var waited: float = 0.0
	while not Pickup.active.is_empty() and waited < pickup_wait_limit:
		await _wait(_PICKUP_POLL)
		waited += _PICKUP_POLL


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_timer.start(seconds)
	await _timer.timeout
