extends Node
## Regression test for the level-up screen and its place between waves. Run
## this scene (F6) and read the Output panel. It takes about ten seconds.

const _SCREEN_SCENE: PackedScene = preload("res://scenes/ui/level_up_screen.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _failures: int = 0
var _checks: int = 0
var _closed_count: int = 0


func _ready() -> void:
	# The screen pauses the game; the test must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_screen()
	await _test_between_waves()
	print("Level-up screen tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _check_text(what: String, label: Label, expected: String) -> void:
	_checks += 1
	if label.text != expected:
		_failures += 1
		print("FAIL  %s: got '%s', expected '%s'" % [what, label.text, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _test_screen() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(5000, 5000)
	add_child(player)
	var screen: LevelUpScreen = _SCREEN_SCENE.instantiate() as LevelUpScreen
	add_child(screen)
	screen.closed.connect(func() -> void: _closed_count += 1)
	await _wait(2)
	player.weapons.firing_enabled = false

	var grid: GridContainer = screen.get_node("%StatGrid") as GridContainer
	var derived: VBoxContainer = screen.get_node("%DerivedList") as VBoxContainer
	var points_label: Label = screen.get_node("%PointsLabel") as Label
	var done: Button = screen.get_node("%DoneButton") as Button
	var reset: Button = screen.get_node("%ResetButton") as Button
	# Each stat row is: name, value, minus, plus.
	var value_of: Callable = func(stat: int) -> Label: return grid.get_child(stat * 4 + 1) as Label
	var minus_of: Callable = func(stat: int) -> Button: return grid.get_child(stat * 4 + 2) as Button
	var plus_of: Callable = func(stat: int) -> Button: return grid.get_child(stat * 4 + 3) as Button
	var derived_line: Callable = func(index: int) -> Label: return derived.get_child(index) as Label

	_check("the screen starts hidden", float(screen.is_open()), 0.0)
	_check("one row per primary stat", grid.get_child_count(), 6 * 4)
	_check("one line per derived value", derived.get_child_count(), 10)
	_check("rows are labelled", float((grid.get_child(0) as Label).text == "STR" and (grid.get_child(20) as Label).text == "LUK"), 1.0)

	player.progression.add_xp(player.progression.config.total_xp_for_level(3))
	_check("two levels give 10 points", player.progression.stat_points, 10)
	screen.open(player)
	_check("open shows the screen", float(screen.is_open()), 1.0)
	_check("open pauses the game", float(get_tree().paused), 1.0)
	_check_text("points to spend are shown", points_label, "10 points to spend")
	await get_tree().process_frame
	var panel_rect: Rect2 = (screen.get_node("Root/Center/Panel") as Control).get_global_rect()
	print("INFO  level-up panel is %d x %d px" % [panel_rect.size.x, panel_rect.size.y])
	_check("the panel fits on the 480 x 270 screen", float(Rect2(0, 0, 480, 270).encloses(panel_rect)), 1.0)
	_check("nothing planned, nothing to reset", float(reset.disabled), 1.0)
	_check("no minus before a plus", float((minus_of.call(0) as Button).disabled), 1.0)

	(plus_of.call(StatBlock.Stat.STR) as Button).pressed.emit()
	(plus_of.call(StatBlock.Stat.STR) as Button).pressed.emit()
	_check_text("a planned point shows next to the stat", value_of.call(StatBlock.Stat.STR), "0 +2")
	_check_text("planned points come off the total", points_label, "8 points to spend")
	_check("planning spends nothing yet", player.stats.strength, 0)
	var defense_line: Label = derived_line.call(4)
	_check("the preview shows the change", float(defense_line.text == "Defense  0% > 4%"), 1.0)
	_check("a changed value is highlighted", float(defense_line.has_theme_color_override(&"font_color")), 1.0)
	_check_text("an unchanged value has no arrow", derived_line.call(0), "Max HP  100")
	_check("an unchanged value is not highlighted", float((derived_line.call(0) as Label).has_theme_color_override(&"font_color")), 0.0)

	(minus_of.call(StatBlock.Stat.STR) as Button).pressed.emit()
	_check_text("minus takes a planned point back", value_of.call(StatBlock.Stat.STR), "0 +1")
	reset.pressed.emit()
	_check_text("reset clears the plan", value_of.call(StatBlock.Stat.STR), "0")
	_check_text("reset gives every point back", points_label, "10 points to spend")

	for i: int in 3:
		(plus_of.call(StatBlock.Stat.VIT) as Button).pressed.emit()
	for i: int in 7:
		(plus_of.call(StatBlock.Stat.AGI) as Button).pressed.emit()
	_check_text("the last point can be planned", points_label, "0 points to spend")
	_check("with no points left, every plus is off", float((plus_of.call(StatBlock.Stat.LUK) as Button).disabled), 1.0)
	_check("with no points left, nothing more can be planned", float(screen.plan_point(StatBlock.Stat.LUK)), 0.0)
	_check_text("max hp preview", derived_line.call(0), "Max HP  100 > 118")
	_check_text("move speed preview", derived_line.call(7), "Move  90 > 94")

	done.pressed.emit()
	_check("done spends the plan (VIT)", player.stats.vitality, 3)
	_check("done spends the plan (AGI)", player.stats.agility, 7)
	_check("no points are left", player.progression.stat_points, 0)
	_check("the spent points reach the player's health", player.health.max_hp, 118)
	_check("done hides the screen", float(screen.is_open()), 0.0)
	_check("done unpauses the game", float(get_tree().paused), 0.0)
	_check("closed is emitted", _closed_count, 1)

	player.progression.add_xp(player.progression.get_xp_required())
	screen.open(player)
	screen.plan_point(StatBlock.Stat.LUK)
	screen.plan_point(StatBlock.Stat.LUK)
	screen.confirm()
	_check("points left unspent are kept", player.progression.stat_points, 3)
	_check("the planned ones were spent", player.stats.luck, 2)
	screen.open(player)
	_check("reopening starts with no plan", screen.get_points_left(), 3)
	screen.confirm()
	player.queue_free()
	screen.queue_free()
	await _wait(2)


func _test_between_waves() -> void:
	var main: Node = _MAIN_SCENE.instantiate()
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	var short_wave := WaveData.new()
	short_wave.duration = 1.0
	short_wave.spawn_interval = 30.0
	spawner.waves = [short_wave, short_wave.duplicate() as WaveData]
	add_child(main)
	var player: Player = main.get_node("Player") as Player
	var screen: LevelUpScreen = main.get_node("LevelUpScreen") as LevelUpScreen
	player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	player.weapons.firing_enabled = false
	player.progression.add_xp(player.progression.get_xp_required())
	_check("the screen stays shut during a wave", float(screen.is_open()), 0.0)
	await _wait(30)
	_check("still shut in the middle of the wave", float(screen.is_open()), 0.0)
	await _wait(45)
	_check("the screen opens when the wave ends", float(screen.is_open()), 1.0)
	_check("the game is paused behind it", float(get_tree().paused), 1.0)
	await _wait(300)
	_check("the next wave waits for the player", spawner.current_wave_number, 1)
	(screen.get_node("%DoneButton") as Button).pressed.emit()
	await _wait(60)
	_check("the pause between waves follows", spawner.current_wave_number, 1)
	await _wait(150)
	_check("then the next wave starts", spawner.current_wave_number, 2)
	main.queue_free()
	Enemy.despawn_all()
	get_tree().paused = false
	await _wait(2)
