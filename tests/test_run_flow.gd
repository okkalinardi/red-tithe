extends Node
## Regression test for the run flow: playing, the break between waves,
## victory, death, the game-over panel and a restart that resets everything.
## Run this scene (F6) and read the Output panel. It takes about fifteen
## seconds.
##
## The real main scene is made the current scene, so that restart can reload
## it while this test node, which sits beside it, keeps running.

const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _PANEL_SCENE: PackedScene = preload("res://scenes/ui/game_over_panel.tscn")
const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")

var _failures: int = 0
var _checks: int = 0
var _run_ended: Array[bool] = []
var _states: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.run_ended.connect(func(victory: bool) -> void: _run_ended.append(victory))
	_test_panel()
	await _test_victory_and_restart()
	await _test_death_and_restart()
	print("Run flow tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _test_panel() -> void:
	var panel: GameOverPanel = _PANEL_SCENE.instantiate() as GameOverPanel
	add_child(panel)
	_check("the panel starts hidden", float(panel.is_open()), 0.0)
	panel.show_result(false, 4, 10, 135.7, 87, 6)
	_check("show_result shows it", float(panel.is_open()), 1.0)
	_check("death title", float((panel.get_node("%Title") as Label).text == "YOU DIED"), 1.0)
	var summary: String = (panel.get_node("%Summary") as Label).text
	_check("summary has the wave", float(summary.contains("Wave 4/10")), 1.0)
	_check("summary has the time as minutes and seconds", float(summary.contains("Time 2:15")), 1.0)
	_check("summary has the kills", float(summary.contains("Kills 87")), 1.0)
	_check("summary has the level", float(summary.contains("Level 6")), 1.0)
	panel.show_result(true, 10, 10, 360.0, 500, 12)
	_check("victory title", float((panel.get_node("%Title") as Label).text == "VICTORY"), 1.0)
	var requests: Array[int] = [0]
	panel.restart_requested.connect(func() -> void: requests[0] += 1)
	(panel.get_node("%RestartButton") as Button).pressed.emit()
	_check("the restart button asks for a restart", requests[0], 1)
	panel.queue_free()


## Puts a fresh main scene in charge, as the game would at launch.
func _start_main(waves: Array[WaveData]) -> Node:
	var main: Node = _MAIN_SCENE.instantiate()
	if not waves.is_empty():
		(main.get_node("WaveSpawner") as WaveSpawner).waves = waves
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await _wait(2)
	return main


func _short_wave() -> WaveData:
	var wave := WaveData.new()
	wave.duration = 1.0
	wave.spawn_interval = 30.0
	var entry := WaveSpawnEntry.new()
	entry.enemy = _RAT
	wave.entries.append(entry)
	return wave


## The reloaded scene, once restart has replaced [param old_main].
func _wait_for_reload(old_main: Node) -> Node:
	for i: int in 30:
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current != old_main and current.is_node_ready():
			return current
	return null


func _test_victory_and_restart() -> void:
	var main: Node = await _start_main([_short_wave(), _short_wave()])
	var flow: RunFlow = main.get_node("RunFlow") as RunFlow
	var player: Player = main.get_node("Player") as Player
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	var panel: GameOverPanel = main.get_node("GameOverPanel") as GameOverPanel
	flow.phase_changed.connect(func(phase: RunFlow.Phase) -> void: _states.append(phase))
	player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	player.weapons.firing_enabled = false

	_check("the run starts in PLAYING", flow.phase, RunFlow.Phase.PLAYING)
	_check("RunState is running", float(RunState.is_running), 1.0)
	_check("wave 1 has started", spawner.current_wave_number, 1)
	await _wait(70)
	_check("after the wave, BETWEEN_WAVES", flow.phase, RunFlow.Phase.BETWEEN_WAVES)
	var shop: ShopScreen = main.get_node("ShopScreen") as ShopScreen
	await _wait(10)
	_check("the shop opens between waves", float(shop.is_open()), 1.0)
	_check("the shop does not pause the game (regen keeps running)", float(get_tree().paused), 0.0)
	_check("the player's controls are locked while shopping", float(player.controls_enabled), 0.0)
	await _wait(240)
	_check("the next wave waits for the shop", spawner.current_wave_number, 1)
	(shop.get_node("%ContinueButton") as Button).pressed.emit()
	_check("leaving the shop gives the controls back", float(player.controls_enabled), 1.0)
	await _wait(200)
	_check("after the break, PLAYING again", flow.phase, RunFlow.Phase.PLAYING)
	_check("on wave 2", spawner.current_wave_number, 2)
	await _wait(80)
	_check("after the last wave, VICTORY", flow.phase, RunFlow.Phase.VICTORY)
	_check("the panel shows", float(panel.is_open()), 1.0)
	_check("no shop after the final wave", float(shop.is_open()), 0.0)
	_check("it says victory", float((panel.get_node("%Title") as Label).text == "VICTORY"), 1.0)
	_check("the game is paused behind it", float(get_tree().paused), 1.0)
	_check("RunState stopped", float(RunState.is_running), 0.0)
	_check("run_ended(true) was emitted", float(str(_run_ended) == "[true]"), 1.0)
	_check("states went PLAYING, BETWEEN, PLAYING, BETWEEN, VICTORY", float(str(_states) == "[2, 1, 2, 4]"), 1.0)

	# Dirty the run so the restart has something to reset.
	RunState.add_gold(40)
	player.progression.add_xp(500)
	var old_pool: ObjectPool = Pools.get_pool(_RAT.scene)
	(panel.get_node("%RestartButton") as Button).pressed.emit()
	var fresh: Node = await _wait_for_reload(main)
	_check("restart reloads the scene", float(fresh != null), 1.0)
	if fresh == null:
		return
	await _wait(2)
	var fresh_player: Player = fresh.get_node("Player") as Player
	var fresh_flow: RunFlow = fresh.get_node("RunFlow") as RunFlow
	_check("the old scene is gone", float(is_instance_valid(main)), 0.0)
	_check("the game is unpaused", float(get_tree().paused), 0.0)
	_check("the new run is PLAYING", fresh_flow.phase, RunFlow.Phase.PLAYING)
	_check("the new run starts at wave 1", RunState.wave, 1)
	_check("gold is reset", RunState.gold, 0)
	_check("kills are reset", RunState.kills, 0)
	_check("RunState is running again", float(RunState.is_running), 1.0)
	_check("the player is back to level 1", fresh_player.progression.level, 1)
	_check("the player has full hp", fresh_player.health.current_hp, fresh_player.health.max_hp)
	_check("the old enemy pool is gone", float(is_instance_valid(old_pool)), 0.0)
	var new_pool: ObjectPool = Pools.get_pool(_RAT.scene)
	_check("a new pool lives in the new scene", float(is_instance_valid(new_pool) and fresh.is_ancestor_of(new_pool)), 1.0)
	_check("the game-over panel is hidden", float((fresh.get_node("GameOverPanel") as GameOverPanel).is_open()), 0.0)
	var stale: int = 0
	for enemy: Enemy in Enemy.active:
		stale += int(not fresh.is_ancestor_of(enemy))
	_check("no enemy from the old run is listed", stale, 0)


func _test_death_and_restart() -> void:
	var main: Node = get_tree().current_scene
	var flow: RunFlow = main.get_node("RunFlow") as RunFlow
	var player: Player = main.get_node("Player") as Player
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	var panel: GameOverPanel = main.get_node("GameOverPanel") as GameOverPanel
	_run_ended.clear()
	await _wait(30)
	# kill() rather than a big hit: a learned Berserk would survive the hit.
	player.health.kill()
	_check("death switches to DEAD", flow.phase, RunFlow.Phase.DEAD)
	_check("spawning stops", float(spawner.is_wave_active()), 0.0)
	_check("RunState stopped", float(RunState.is_running), 0.0)
	_check("run_ended(false) was emitted", float(str(_run_ended) == "[false]"), 1.0)
	_check("the panel waits so the death can be seen", float(panel.is_open()), 0.0)
	await _wait(100)
	_check("then the panel shows", float(panel.is_open()), 1.0)
	_check("it says you died", float((panel.get_node("%Title") as Label).text == "YOU DIED"), 1.0)
	_check("the game is paused", float(get_tree().paused), 1.0)

	panel.restart_requested.emit()
	var fresh: Node = await _wait_for_reload(main)
	_check("restart after death reloads the scene", float(fresh != null), 1.0)
	if fresh == null:
		return
	await _wait(2)
	_check("the new player is alive", float((fresh.get_node("Player") as Player).health.is_alive()), 1.0)
	_check("the new run is PLAYING", (fresh.get_node("RunFlow") as RunFlow).phase, RunFlow.Phase.PLAYING)
	_check("unpaused", float(get_tree().paused), 0.0)
	fresh.queue_free()
	get_tree().current_scene = self
