extends CanvasLayer
## TEMPORARY. Plain text readout of the run, for checking that the systems
## work. Replace it with the real HUD in the HUD task and delete this scene.

var _player: Player
var _spawner: WaveSpawner

@onready var _label: Label = $Label


func setup(player: Player, spawner: WaveSpawner) -> void:
	_player = player
	_spawner = spawner
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _player == null or _spawner == null:
		return
	var health: HealthComponent = _player.health
	var progression: ProgressionComponent = _player.progression
	var lines: PackedStringArray = PackedStringArray([
		"HP %d/%d" % [ceili(health.current_hp), health.max_hp],
		"EXP %d/%d  Lv %d" % [progression.xp, progression.get_xp_required(), progression.level],
		"Points %d stat, %d skill  Gold %d" % [progression.stat_points, progression.skill_points, RunState.gold],
		"Wave %d/%d" % [_spawner.current_wave_number, _spawner.get_wave_count()],
		_get_time_line(health),
		"Enemies %d  Kills %d" % [Enemy.active.size(), RunState.kills],
	])
	_label.text = "\n".join(lines)


func _get_time_line(health: HealthComponent) -> String:
	if not health.is_alive():
		return "Time - (dead)"
	if not _spawner.is_wave_active():
		return "Time - (between waves)"
	if not _spawner.is_wave_timed():
		return "Time - (boss wave)"
	return "Time %.1f" % _spawner.get_time_left()
