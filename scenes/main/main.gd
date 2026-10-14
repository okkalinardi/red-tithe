extends Node2D
## Root of the gameplay scene. Wires the pieces together; holds no game rules.
## The run itself (waves, breaks, death, restart) is [RunFlow].

# Room kept around a spawn point, in pixels: the largest enemy body radius
# plus a little.
const _SPAWN_CLEARANCE: float = 10.0

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _drop_spawner: DropSpawner = $DropSpawner
@onready var _hud: Hud = $Hud
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _shop_screen: ShopScreen = $ShopScreen
@onready var _game_over_panel: GameOverPanel = $GameOverPanel
@onready var _run_flow: RunFlow = $RunFlow


func _ready() -> void:
	# Every pooled enemy, arrow and pickup lives inside this scene.
	Pools.set_host(self)
	var bounds: Rect2i = _arena.get_bounds()
	_player.global_position = Vector2(bounds.get_center())
	_player.set_camera_limits(bounds)

	_wave_spawner.setup(_player, bounds, _arena.is_point_free.bind(_SPAWN_CLEARANCE))
	_drop_spawner.setup(_player.collector)
	_hud.setup(_player, _wave_spawner)
	_run_flow.setup(_player, _wave_spawner, _level_up_screen, _game_over_panel, _shop_screen)
	_run_flow.start_run()
