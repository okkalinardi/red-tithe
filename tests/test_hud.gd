extends Node
## Regression test for the HUD. Run this scene (F6) and read the Output
## panel. It takes about five seconds because a wave timer really runs.

const _HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")

var _failures: int = 0
var _checks: int = 0
var _timer_signals: Array[int] = []


func _ready() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(5000, 5000)
	add_child(player)
	var spawner := WaveSpawner.new()
	var timed := WaveData.new()
	timed.duration = 3.0
	timed.spawn_interval = 30.0
	var boss_wave := WaveData.new()
	boss_wave.duration = 0.0
	boss_wave.spawn_interval = 30.0
	boss_wave.boss = _RAT
	spawner.waves = [timed, boss_wave]
	add_child(spawner)
	spawner.setup(player, Rect2i(4000, 4000, 2000, 2000))
	spawner.time_left_changed.connect(func(seconds: int) -> void: _timer_signals.append(seconds))
	await get_tree().physics_frame
	player.weapons.firing_enabled = false
	player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED

	var hud: Hud = _HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.setup(player, spawner)
	var hp_bar: ProgressBar = hud.get_node("%HpBar") as ProgressBar
	var hp_label: Label = hud.get_node("%HpLabel") as Label
	var xp_bar: ProgressBar = hud.get_node("%XpBar") as ProgressBar
	var level_label: Label = hud.get_node("%LevelLabel") as Label
	var wave_label: Label = hud.get_node("%WaveLabel") as Label
	var timer_label: Label = hud.get_node("%TimerLabel") as Label
	var gold_label: Label = hud.get_node("%GoldLabel") as Label

	_check("the HUD does no per-frame work", float(hud.is_processing() or hud.is_physics_processing()), 0.0)
	_check_text("hp starts full", hp_label, "100/100")
	_check("hp bar max is max hp", hp_bar.max_value, 100)
	_check("hp bar is full", hp_bar.value, 100)
	_check_text("level starts at 1", level_label, "Lv 1")
	_check("xp bar max is the first requirement", xp_bar.max_value, player.progression.get_xp_required())
	_check("xp bar starts empty", xp_bar.value, 0)
	_check_text("gold shows the run's gold", gold_label, str(RunState.gold))
	_check_text("before any wave, it shows wave 1", wave_label, "WAVE 1/2")
	_check_text("before any wave, the timer is a dash", timer_label, "-")

	spawner.start_wave(1)
	_check_text("wave counter follows the wave", wave_label, "WAVE 1/2")
	_check_text("the timer shows the full duration", timer_label, "3")
	await _wait(70)
	_check_text("the timer counts down in whole seconds", timer_label, "2")
	await _wait(130)
	_check("the wave has ended", float(spawner.is_wave_active()), 0.0)
	_check_text("after the wave, the timer is a dash", timer_label, "-")
	_check("the timer sent one signal per second, not per frame", float(str(_timer_signals) == "[3, 2, 1, 0]"), 1.0)

	player.health.take_damage(25.0)
	_check_text("hp text follows damage", hp_label, "75/100")
	_check("hp bar follows damage", hp_bar.value, 75)
	player.stats.vitality = 1
	_check("hp bar max follows max hp", hp_bar.max_value, 106)
	_check("hp text shows the new max", float(hp_label.text.ends_with("/106")), 1.0)

	player.progression.add_xp(4)
	_check("xp bar fills", xp_bar.value, 4)
	player.progression.add_xp(player.progression.get_xp_required() - 4)
	_check_text("level text follows a level-up", level_label, "Lv 2")
	_check("xp bar max follows the new requirement", xp_bar.max_value, player.progression.get_xp_required())
	_check("xp bar empties after the level-up", xp_bar.value, 0)

	RunState.add_gold(5)
	_check_text("gold follows RunState", gold_label, str(RunState.gold))

	spawner.start_wave(2)
	_check_text("wave counter shows wave 2", wave_label, "WAVE 2/2")
	_check_text("a wave without a timer shows BOSS", timer_label, "BOSS")
	spawner.stop()
	Enemy.despawn_all()

	# Layout: every block is on screen and no two blocks overlap.
	await get_tree().process_frame
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(480, 270))
	var blocks: Array[Rect2] = []
	for block_name: String in ["Root/Vitals", "Root/WaveBox", "Root/GoldRow"]:
		var rect: Rect2 = (hud.get_node(block_name) as Control).get_global_rect()
		blocks.append(rect)
		_check("%s is fully on screen" % block_name, float(screen.encloses(rect)), 1.0)
		_check("%s has a size" % block_name, float(rect.size.x > 10.0 and rect.size.y > 5.0), 1.0)
	_check("hp bar and wave counter do not overlap", float(blocks[0].intersects(blocks[1])), 0.0)
	_check("wave counter and gold do not overlap", float(blocks[1].intersects(blocks[2])), 0.0)
	var hp_rect: Rect2 = hp_bar.get_global_rect()
	_check("the hp text sits inside the hp bar", float(hp_rect.grow(3.0).encloses(hp_label.get_global_rect())), 1.0)

	var main: Node = _MAIN_SCENE.instantiate()
	_check("the main scene has the HUD", float(main.get_node_or_null("Hud") is Hud), 1.0)
	_check("the debug readout is gone", float(main.get_node_or_null("DebugHud") == null), 1.0)
	main.free()
	print("HUD tests: %d checks, %d failed" % [_checks, _failures])


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
