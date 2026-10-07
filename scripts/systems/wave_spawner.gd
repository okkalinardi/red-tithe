class_name WaveSpawner
extends Node
## Runs waves: spawns each wave's enemies just outside the camera view and
## inside the arena, keeps to the alive cap, and ends the wave on its timer
## or when its boss dies.
##
## It never starts the next wave by itself. Whoever runs the game (shop, run
## flow) listens for [signal wave_ended] and calls [method start_next_wave].
## [codeblock]
## spawner.setup(player, arena.get_bounds())
## spawner.start_next_wave()
## [/codeblock]
## It also emits [signal Events.wave_started], [signal Events.wave_completed]
## and [signal Events.boss_defeated], and keeps [member RunState.wave] current.

signal wave_started(number: int)
signal wave_ended(number: int)
## Emitted after [signal wave_ended] of the last wave.
signal all_waves_completed
signal enemy_spawned(enemy: Enemy)

## No setting can raise the number of enemies alive above this.
const HARD_CAP: int = 100
const _RING_ATTEMPTS: int = 12
const _ARENA_ATTEMPTS: int = 24

## The waves in order. Wave 1 is the first entry.
@export var waves: Array[WaveData] = []
## Most enemies alive at once. Cannot exceed [constant HARD_CAP].
@export_range(1, 100) var max_alive: int = HARD_CAP
## Remove the enemies still alive when a wave ends.
@export var clear_enemies_on_wave_end: bool = true

@export_group("Spawn area (pixels)")
## Enemies appear at least this far outside the camera view.
@export var view_margin: float = 24.0
## Width of the band beyond the margin in which they appear.
@export var spawn_band: float = 48.0
## Enemies appear at least this far inside the arena walls.
@export var wall_margin: float = 12.0

## 1 for the first wave. 0 before any wave has started.
var current_wave_number: int = 0
## Replace with a seeded generator to make spawns repeatable in tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _wave: WaveData
var _target: Node2D
var _bounds: Rect2
var _is_active: bool = false
var _time_left: float = 0.0
var _spawn_timer: float = 0.0


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.player_died.connect(stop)


func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer += _wave.spawn_interval
		_spawn_batch()
	if _wave.is_timed():
		_time_left -= delta
		if _time_left <= 0.0:
			_end_wave()


## [param target] is what enemies chase. [param arena_bounds] is the arena
## rectangle in world space. Also creates the enemies ahead of time, so
## nothing is instantiated in the middle of a wave.
func setup(target: Node2D, arena_bounds: Rect2i) -> void:
	_target = target
	_bounds = Rect2(arena_bounds).grow(-wall_margin)
	_prewarm_pools()


## Starts wave [param number] (1 is the first). Returns false if there is no
## such wave. A wave that is running is replaced without its end signal.
func start_wave(number: int) -> bool:
	if number < 1 or number > waves.size() or waves[number - 1] == null:
		return false
	if _target == null:
		push_error("WaveSpawner.setup() must be called before a wave is started.")
		return false
	_wave = waves[number - 1]
	current_wave_number = number
	_time_left = _wave.duration
	_spawn_timer = 0.0
	_is_active = true
	RunState.set_wave(number)
	wave_started.emit(number)
	Events.wave_started.emit(number)
	if _wave.boss != null:
		_spawn(_wave.boss)
	elif not _wave.is_timed():
		push_warning("Wave %d has no timer and no boss, so it can never end." % number)
	return true


## Starts the wave after the current one. Returns false after the last wave.
func start_next_wave() -> bool:
	return start_wave(current_wave_number + 1)


## Stops spawning and the timer without ending the wave. Enemies stay.
func stop() -> void:
	_is_active = false


func is_wave_active() -> bool:
	return _is_active


## Seconds left on the wave timer. 0 for a wave without a timer.
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _is_active and _wave.is_timed() else 0.0


## True if the running wave ends on a timer rather than on its boss dying.
func is_wave_timed() -> bool:
	return _is_active and _wave.is_timed()


func get_wave_count() -> int:
	return waves.size()


func _get_alive_limit() -> int:
	return mini(mini(max_alive, _wave.max_alive), HARD_CAP)


func _spawn_batch() -> void:
	var limit: int = _get_alive_limit()
	for i: int in _wave.batch_size:
		if Enemy.active.size() >= limit:
			return
		var enemy_data: EnemyData = _wave.pick_enemy(rng)
		if enemy_data == null:
			return
		_spawn(enemy_data)


func _spawn(enemy_data: EnemyData) -> void:
	var enemy: Enemy = Enemy.spawn(
		enemy_data,
		_pick_spawn_position(),
		_target,
		_wave.hp_multiplier,
		_wave.damage_multiplier,
	)
	if enemy != null:
		enemy_spawned.emit(enemy)


# A point inside the arena and outside what the camera shows. It first tries
# the band just beyond the screen edge, so enemies walk in from nearby; near
# an arena corner most of that band is outside the arena, so it then tries
# anywhere in the arena that is off screen.
func _pick_spawn_position() -> Vector2:
	var hidden_from: Rect2 = _get_view_rect().grow(view_margin)
	for attempt: int in _RING_ATTEMPTS:
		var point: Vector2 = _random_point_in_band(hidden_from)
		if _bounds.has_point(point):
			return point
	for attempt: int in _ARENA_ATTEMPTS:
		var point: Vector2 = _random_point_in(_bounds)
		if not hidden_from.has_point(point):
			return point
	# The camera shows the whole arena: use the corner furthest from the target.
	var corners: Array[Vector2] = [
		_bounds.position,
		Vector2(_bounds.end.x, _bounds.position.y),
		Vector2(_bounds.position.x, _bounds.end.y),
		_bounds.end,
	]
	var furthest: Vector2 = corners[0]
	for corner: Vector2 in corners:
		if corner.distance_squared_to(_target.global_position) > furthest.distance_squared_to(_target.global_position):
			furthest = corner
	return furthest


# A point in the band of width spawn_band around [param inner]. The band is
# four strips (top, bottom, left, right); one is picked by its share of the
# area, so every part of the band is equally likely.
func _random_point_in_band(inner: Rect2) -> Vector2:
	var outer: Rect2 = inner.grow(spawn_band)
	var strips: Array[Rect2] = [
		Rect2(outer.position, Vector2(outer.size.x, spawn_band)),
		Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, spawn_band)),
		Rect2(Vector2(outer.position.x, inner.position.y), Vector2(spawn_band, inner.size.y)),
		Rect2(Vector2(inner.end.x, inner.position.y), Vector2(spawn_band, inner.size.y)),
	]
	var total_area: float = 0.0
	for strip: Rect2 in strips:
		total_area += strip.get_area()
	var roll: float = rng.randf() * total_area
	for strip: Rect2 in strips:
		roll -= strip.get_area()
		if roll < 0.0:
			return _random_point_in(strip)
	return _random_point_in(strips[0])


func _random_point_in(rect: Rect2) -> Vector2:
	return Vector2(
		rng.randf_range(rect.position.x, rect.end.x),
		rng.randf_range(rect.position.y, rect.end.y),
	)


# What the camera shows, in world space.
func _get_view_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = _target.global_position
	var camera: Camera2D = viewport.get_camera_2d()
	if camera != null:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - size * 0.5, size)


func _end_wave() -> void:
	var number: int = current_wave_number
	_is_active = false
	if clear_enemies_on_wave_end:
		Enemy.despawn_all()
	wave_ended.emit(number)
	Events.wave_completed.emit(number)
	if number >= waves.size():
		all_waves_completed.emit()


func _on_enemy_died(data: EnemyData, _position: Vector2) -> void:
	if not _is_active or _wave.boss == null or data != _wave.boss:
		return
	Events.boss_defeated.emit()
	if not _wave.is_timed():
		_end_wave()


# One enemy scene can serve several kinds of enemy, so the need is counted
# per scene: the largest share any wave gives it, with some room to spare.
func _prewarm_pools() -> void:
	var needed: Dictionary[PackedScene, int] = {}
	for wave: WaveData in waves:
		if wave == null:
			continue
		var limit: int = mini(mini(max_alive, wave.max_alive), HARD_CAP)
		var total_weight: float = 0.0
		for entry: WaveSpawnEntry in wave.entries:
			if entry != null and entry.enemy != null:
				total_weight += entry.weight
		var per_scene: Dictionary[PackedScene, float] = {}
		for entry: WaveSpawnEntry in wave.entries:
			if entry == null or entry.enemy == null or entry.enemy.scene == null or total_weight <= 0.0:
				continue
			per_scene[entry.enemy.scene] = per_scene.get(entry.enemy.scene, 0.0) + entry.weight / total_weight
		for scene: PackedScene in per_scene:
			var count: int = mini(ceili(limit * per_scene[scene] * 1.25) + 2, limit)
			needed[scene] = maxi(needed.get(scene, 0), count)
		if wave.boss != null and wave.boss.scene != null:
			needed[wave.boss.scene] = maxi(needed.get(wave.boss.scene, 0), 1)
	for scene: PackedScene in needed:
		Pools.prewarm(scene, needed[scene])
