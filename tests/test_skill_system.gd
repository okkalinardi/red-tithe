extends Node
## Regression test for the skill system: SkillData, SkillHolder (HP cost,
## cooldown, hotkeys, unlocking) and the HUD skill slots. Run this scene (F6)
## and read the Output panel. Cooldowns are advanced by hand, so it finishes
## at once.

const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const _CONSUME: SkillData = preload("res://data/skills/consume.tres")
const _SPLATTER: SkillData = preload("res://data/skills/blood_splatter.tres")
const _DASH: SkillData = preload("res://data/skills/dash.tres")
const _BERSERK: SkillData = preload("res://data/skills/berserk.tres")

const CONSUME: int = 0
const SPLATTER: int = 1
const DASH: int = 2
const BERSERK: int = 3

var _failures: int = 0
var _checks: int = 0
var _refusals: Array[int] = []
var _casts: Array[int] = []
var _ended: Array[int] = []
var _scene_unlocks_all: bool = false


func _ready() -> void:
	_test_skill_data()
	_test_data_files()
	var player: Player = await _new_player()
	_test_unlocking(player)
	_test_cost_and_cooldown(player)
	_test_cost_never_kills(player)
	_test_automatic_and_wave_reset(player)
	_test_hotkeys(player)
	_test_skill_refusal(player)
	await _test_hud(player)
	_test_death(player)
	print("Skill system tests: %d checks, %d failed" % [_checks, _failures])


func _new_player() -> Player:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(5000, 5000)
	# Remember how the scene is saved, then test from locked skills anyway.
	var holder: SkillHolder = player.get_node("Skills") as SkillHolder
	_scene_unlocks_all = holder.unlock_all_on_start
	holder.unlock_all_on_start = false
	add_child(player)
	await get_tree().physics_frame
	player.weapons.firing_enabled = false
	player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	# The test advances cooldowns and regen itself.
	player.skills.process_mode = Node.PROCESS_MODE_DISABLED
	player.health.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.cast_refused.connect(func(_slot: int, reason: SkillHolder.CastResult) -> void: _refusals.append(reason))
	player.skills.skill_cast.connect(func(slot: int) -> void: _casts.append(slot))
	player.skills.cooldown_ended.connect(func(slot: int) -> void: _ended.append(slot))
	return player


func _advance(holder: SkillHolder, seconds: float) -> void:
	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < seconds - 0.0001:
		holder._physics_process(step)
		elapsed += step


func _set_hp(player: Player, hp: float) -> void:
	player.health.current_hp = hp


func _test_skill_data() -> void:
	var data := SkillData.new()
	data.base_value = 50.0
	_check("level 1 is the base value", data.get_value(1), 50.0)
	_check("each level adds 20%", data.get_value(2), 60.0)
	_check("level 5 is +80%", data.get_value(5), 90.0)
	_check("levels above the max are clamped", data.get_value(9), 90.0)
	_check("level 0 counts as level 1", data.get_value(0), 50.0)
	_check("crit is off by default", float(data.can_crit), 0.0)


func _test_data_files() -> void:
	# Numbers from GDD section 3, revision 5.
	_check("Consume costs 5 HP", _CONSUME.hp_cost, 5.0)
	_check("Consume cooldown 8 s", _CONSUME.cooldown, 8.0)
	_check("Consume reach 32 px", _CONSUME.reach, 32.0)
	_check("Blood Splatter costs 20 HP", _SPLATTER.hp_cost, 20.0)
	_check("Blood Splatter cooldown 3 s", _SPLATTER.cooldown, 3.0)
	_check("Blood Splatter base damage 30", _SPLATTER.base_value, 30.0)
	_check("Blood Splatter radius 32 px", _SPLATTER.reach, 32.0)
	_check("Dash costs 8 HP", _DASH.hp_cost, 8.0)
	_check("Dash cooldown 2 s", _DASH.cooldown, 2.0)
	_check("Dash base distance 48 px", _DASH.base_value, 48.0)
	_check("Berserk is free", _BERSERK.hp_cost, 0.0)
	_check("Berserk cooldown 30 s", _BERSERK.cooldown, 30.0)
	_check("Berserk lasts 10 s", _BERSERK.base_value, 10.0)
	_check("Berserk is automatic", float(_BERSERK.is_automatic()), 1.0)
	_check("Berserk resets every wave", float(_BERSERK.resets_on_new_wave), 1.0)
	for data: SkillData in [_CONSUME, _SPLATTER, _DASH, _BERSERK]:
		_check("%s: 5 levels" % data.id, data.max_level, 5)
		_check("%s: cannot crit in v1.0" % data.id, float(data.can_crit), 0.0)
	for data: SkillData in [_CONSUME, _SPLATTER, _DASH]:
		_check("%s: is active" % data.id, float(data.is_automatic()), 0.0)
		_check("%s: its hotkey exists" % data.id, float(InputMap.has_action(data.input_action)), 1.0)


func _test_unlocking(player: Player) -> void:
	var skills: SkillHolder = player.skills
	_check("the player has 4 skill slots", skills.get_slot_count(), 4)
	_check("slots are in GDD order", float(skills.get_skill_data(0) == _CONSUME and skills.get_skill_data(3) == _BERSERK), 1.0)
	_check("the shipped player does not unlock everything (untick Player/Skills unlock_all_on_start)", float(_scene_unlocks_all), 0.0)
	for slot: int in 4:
		_check("slot %d starts locked" % slot, skills.get_level(slot), 0)
	_refusals.clear()
	_check("a locked skill is refused", skills.try_cast(SPLATTER), SkillHolder.CastResult.LOCKED)
	_check("the refusal is signalled", float(_same(_refusals, [SkillHolder.CastResult.LOCKED])), 1.0)
	_check("a refused cast costs nothing", player.health.current_hp, 100.0)

	_check("learn unlocks", float(skills.learn(SPLATTER)), 1.0)
	_check("unlocked at level 1", skills.get_level(SPLATTER), 1)
	_check("a behaviour node is created", float(skills.get_skill(SPLATTER) is Skill), 1.0)
	_check("the behaviour node knows its caster", float(skills.get_skill(SPLATTER).caster == player), 1.0)
	for i: int in 4:
		skills.learn(SPLATTER)
	_check("upgrades reach level 5", skills.get_level(SPLATTER), 5)
	_check("the behaviour node follows the level", skills.get_skill(SPLATTER).level, 5)
	_check("the behaviour node's value grows", skills.get_skill(SPLATTER).get_value(), 54.0)
	_check("no level 6", float(skills.learn(SPLATTER)), 0.0)
	_check("can_learn is false at max", float(skills.can_learn(SPLATTER)), 0.0)
	_check("one node per skill, however often upgraded", skills.get_child_count(), 1)
	_check("an invalid slot cannot be learned", float(skills.learn(9)), 0.0)
	for slot: int in [CONSUME, DASH, BERSERK]:
		skills.learn(slot)


func _test_cost_and_cooldown(player: Player) -> void:
	var skills: SkillHolder = player.skills
	_set_hp(player, 100.0)
	_casts.clear()
	_ended.clear()
	_check("Blood Splatter casts", skills.try_cast(SPLATTER), SkillHolder.CastResult.OK)
	_check("it spent 20 HP", player.health.current_hp, 80.0)
	_check("skill_cast signalled", float(_same(_casts, [SPLATTER])), 1.0)
	_check("cooldown is the full 3 s", skills.get_cooldown_left(SPLATTER), 3.0)
	_check("cooldown ratio starts at 1", skills.get_cooldown_ratio(SPLATTER), 1.0)
	_check("cast again at once is refused", skills.try_cast(SPLATTER), SkillHolder.CastResult.ON_COOLDOWN)
	_check("a cooldown refusal costs nothing", player.health.current_hp, 80.0)
	_check("other skills are not on cooldown", skills.get_cooldown_left(DASH), 0.0)
	_advance(skills, 1.5)
	_check("half way through the cooldown", skills.get_cooldown_ratio(SPLATTER), 0.5, 0.02)
	_advance(skills, 1.55)
	_check("cooldown over after 3 s", skills.get_cooldown_left(SPLATTER), 0.0)
	_check("cooldown_ended signalled once", float(_same(_ended, [SPLATTER])), 1.0)
	_check("castable again", skills.try_cast(SPLATTER), SkillHolder.CastResult.OK)
	_check("the second cast spent 20 more", player.health.current_hp, 60.0)
	skills.reset_cooldown(SPLATTER)
	_check("Defense never reduces a cost", float(player.stats.damage_reduction == 0.0), 1.0)
	player.stats.strength = 50
	_check("with STR 50, Blood Splatter still costs 20", float(skills.try_cast(SPLATTER) == SkillHolder.CastResult.OK and player.health.current_hp == 40.0), 1.0)
	player.stats.strength = 0
	skills.reset_cooldown(SPLATTER)


func _test_cost_never_kills(player: Player) -> void:
	var skills: SkillHolder = player.skills
	_set_hp(player, 20.0)
	_refusals.clear()
	_check("a cost equal to HP is refused", skills.try_cast(SPLATTER), SkillHolder.CastResult.NOT_ENOUGH_HP)
	_check("the refusal says why", float(_same(_refusals, [SkillHolder.CastResult.NOT_ENOUGH_HP])), 1.0)
	_check("HP is untouched", player.health.current_hp, 20.0)
	_check("no cooldown after a refusal", skills.get_cooldown_left(SPLATTER), 0.0)
	_check("check_cast agrees and changes nothing", skills.check_cast(SPLATTER), SkillHolder.CastResult.NOT_ENOUGH_HP)
	_check("a cheaper skill still casts", skills.try_cast(DASH), SkillHolder.CastResult.OK)
	_check("Dash spent 8", player.health.current_hp, 12.0)
	_set_hp(player, 9.0)
	skills.reset_cooldown(DASH)
	_check("a cost leaving exactly 1 HP is allowed", skills.try_cast(DASH), SkillHolder.CastResult.OK)
	_check("left at 1 HP, alive", float(player.health.current_hp == 1.0 and player.health.is_alive()), 1.0)
	skills.reset_cooldown(DASH)
	_set_hp(player, 100.0)


func _test_automatic_and_wave_reset(player: Player) -> void:
	var skills: SkillHolder = player.skills
	_check("Berserk cannot be cast by key", skills.try_cast(BERSERK), SkillHolder.CastResult.WRONG_ACTIVATION)
	_check("an active skill cannot be triggered", skills.trigger(DASH), SkillHolder.CastResult.WRONG_ACTIVATION)
	_set_hp(player, 1.0)
	_check("Berserk triggers at 1 HP", skills.trigger(BERSERK), SkillHolder.CastResult.OK)
	_check("Berserk is free", player.health.current_hp, 1.0)
	_check("Berserk goes on its 30 s cooldown", skills.get_cooldown_left(BERSERK), 30.0)
	_check("Berserk once per cooldown", skills.trigger(BERSERK), SkillHolder.CastResult.ON_COOLDOWN)
	_set_hp(player, 100.0)
	skills.try_cast(SPLATTER)
	_ended.clear()
	Events.wave_started.emit(2)
	_check("a new wave resets Berserk", skills.get_cooldown_left(BERSERK), 0.0)
	_check("the reset is signalled", float(_same(_ended, [BERSERK])), 1.0)
	_check("a new wave does not reset other skills", skills.get_cooldown_left(SPLATTER), 3.0)
	skills.reset_cooldown(SPLATTER)
	_set_hp(player, 100.0)


func _test_hotkeys(player: Player) -> void:
	var skills: SkillHolder = player.skills
	_casts.clear()
	skills._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	_check("right mouse button casts Blood Splatter", float(_same(_casts, [SPLATTER])), 1.0)
	_check("the key cast paid the cost", player.health.current_hp, 80.0)
	skills.reset_cooldown(SPLATTER)
	_casts.clear()
	skills._unhandled_input(_key(KEY_SHIFT, true))
	_check("a held key's repeats do not cast", _casts.size(), 0)
	var release := _mouse(MOUSE_BUTTON_RIGHT)
	release.pressed = false
	skills._unhandled_input(release)
	_check("releasing a button does not cast", _casts.size(), 0)
	_refusals.clear()
	skills._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	_check("left mouse tries Consume (refused: nothing in reach)", float(_same(_refusals, [SkillHolder.CastResult.NO_TARGET])), 1.0)
	skills._unhandled_input(_key(KEY_SHIFT, false))
	_check("left Shift casts Dash", float(_same(_casts, [DASH])), 1.0)
	var right_shift := _key(KEY_SHIFT, false)
	right_shift.location = KEY_LOCATION_RIGHT
	skills._unhandled_input(right_shift)
	_check("right Shift does not dash", float(_same(_casts, [DASH])), 1.0)
	var walk_while_dashing := _key(KEY_W, false)
	walk_while_dashing.shift_pressed = true
	_check("holding Shift does not block walking", float(walk_while_dashing.is_action_pressed(&"move_up")), 1.0)
	skills._unhandled_input(_key(KEY_F, false))
	_check("no key casts Berserk", float(_same(_casts, [DASH])), 1.0)
	for slot: int in 4:
		skills.reset_cooldown(slot)
	_set_hp(player, 100.0)


func _test_skill_refusal(player: Player) -> void:
	# A skill whose own condition fails (Consume with nothing in reach) must
	# not cost HP or start its cooldown.
	var script := GDScript.new()
	script.source_code = "extends Skill\nvar allow: bool = false\nvar activations: int = 0\nfunc can_activate() -> bool:\n\treturn allow\nfunc _activate() -> void:\n\tactivations += 1\n"
	script.reload()
	var template := Node2D.new()
	template.set_script(script)
	var scene := PackedScene.new()
	scene.pack(template)
	template.free()
	var data := SkillData.new()
	data.id = &"picky"
	data.input_action = &"skill_1"
	data.hp_cost = 10.0
	data.cooldown = 5.0
	data.skill_scene = scene
	var holder := SkillHolder.new()
	holder.skills = [data]
	player.add_child(holder)
	holder.setup(player)
	holder.learn(0)
	var skill: Skill = holder.get_skill(0)
	_check("the skill scene is used", float(skill.get_script() == script), 1.0)
	_check("a skill with no target is refused", holder.try_cast(0), SkillHolder.CastResult.NO_TARGET)
	_check("no HP spent without a target", player.health.current_hp, 100.0)
	_check("no cooldown without a target", holder.get_cooldown_left(0), 0.0)
	_check("not activated", skill.get("activations"), 0)
	skill.set("allow", true)
	_check("with a target it casts", holder.try_cast(0), SkillHolder.CastResult.OK)
	_check("activated exactly once", skill.get("activations"), 1)
	_check("paid once", player.health.current_hp, 90.0)
	holder.queue_free()
	_set_hp(player, 100.0)


func _test_hud(player: Player) -> void:
	var skills: SkillHolder = player.skills
	var spawner := WaveSpawner.new()
	var wave := WaveData.new()
	wave.spawn_interval = 30.0
	spawner.waves = [wave]
	add_child(spawner)
	spawner.setup(player, Rect2i(4000, 4000, 2000, 2000))
	# A fresh player for the HUD, so locked slots can be seen too.
	var fresh: Player = await _new_player()
	var hud: Hud = _HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.setup(fresh, spawner)
	await get_tree().process_frame
	var bar: HBoxContainer = hud.get_node("%SkillBar") as HBoxContainer
	_check("one HUD slot per skill", bar.get_child_count(), 4)
	var slots: Array[SkillSlot] = []
	for child: Node in bar.get_children():
		slots.append(child as SkillSlot)
	var keys: Array[String] = []
	var costs: Array[String] = []
	for slot: SkillSlot in slots:
		keys.append((slot.get_node("%KeyLabel") as Label).text)
		costs.append((slot.get_node("%CostLabel") as Label).text)
	_check("hotkeys shown", float(_same(keys, ["LMB", "RMB", "Shift", "AUTO"])), 1.0)
	if not _same(keys, ["LMB", "RMB", "Shift", "AUTO"]):
		print("      hotkeys were %s" % [keys])
	_check("HP costs shown", float(_same(costs, ["5", "20", "8", "-"])), 1.0)
	var box: Control = slots[SPLATTER].get_node("%Box") as Control
	_check("locked slots are dimmed", box.modulate.a, slots[SPLATTER].locked_alpha)
	_check("slots do no per-frame work when idle", float(slots.any(func(s: SkillSlot) -> bool: return s.is_processing())), 0.0)
	fresh.skills.learn(SPLATTER)
	_check("an unlocked slot is bright", box.modulate.a, 1.0)

	var cost_label: Label = slots[SPLATTER].get_node("%CostLabel") as Label
	var cooldown_label: Label = slots[SPLATTER].get_node("%CooldownLabel") as Label
	var cooldown_bar: ProgressBar = slots[SPLATTER].get_node("%CooldownBar") as ProgressBar
	fresh.skills.process_mode = Node.PROCESS_MODE_INHERIT
	fresh.skills.try_cast(SPLATTER)
	_check("the cooldown overlay appears", float(cooldown_bar.visible), 1.0)
	_check("the cooldown seconds appear", float(cooldown_label.visible and cooldown_label.text == "3"), 1.0)
	_check("only the cooling slot processes", float(slots[SPLATTER].is_processing() and not slots[DASH].is_processing()), 1.0)
	# Cooldowns tick on physics frames (60 per second).
	for i: int in 70:
		await get_tree().physics_frame
	_check("the seconds count down", float(cooldown_label.text == "2" or cooldown_label.text == "1"), 1.0)
	fresh.skills.reset_cooldown(SPLATTER)
	_check("the overlay hides when ready", float(cooldown_bar.visible), 0.0)
	_check("the slot stops processing when ready", float(slots[SPLATTER].is_processing()), 0.0)

	fresh.health.current_hp = 15.0
	fresh.health.take_damage(1.0)
	_check("an unaffordable cost turns red", float(cost_label.get_theme_color(&"font_color") == slots[SPLATTER].unaffordable_color), 1.0)
	fresh.health.heal(50.0)
	_check("an affordable cost is normal", float(cost_label.get_theme_color(&"font_color") == slots[SPLATTER].cost_color), 1.0)
	fresh.skills.try_cast(DASH)
	_check("a refused cast flashes the slot", float((slots[DASH].get_node("%Box") as Control).self_modulate != Color.WHITE), 1.0)

	var screen := Rect2(Vector2.ZERO, Vector2(480, 270))
	var bar_rect: Rect2 = bar.get_global_rect()
	_check("the skill bar is on screen", float(screen.encloses(bar_rect)), 1.0)
	_check("the skill bar sits in the bottom half", float(bar_rect.position.y > 135.0), 1.0)
	for block_name: String in ["Root/Vitals", "Root/WaveBox", "Root/GoldRow"]:
		var rect: Rect2 = (hud.get_node(block_name) as Control).get_global_rect()
		_check("the skill bar does not overlap %s" % block_name, float(bar_rect.intersects(rect)), 0.0)
	for slot: SkillSlot in slots:
		_check("each slot is inside the bar", float(bar_rect.grow(1.0).encloses(slot.get_global_rect())), 1.0)
	hud.queue_free()
	spawner.queue_free()
	fresh.queue_free()


func _test_death(player: Player) -> void:
	var skills: SkillHolder = player.skills
	player.health.process_mode = Node.PROCESS_MODE_INHERIT
	player.health.take_damage(9999.0)
	_check("a dead player cannot cast", skills.try_cast(DASH), SkillHolder.CastResult.DISABLED)
	_check("death switches casting off", float(skills.casting_enabled), 0.0)


func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


func _key(keycode: Key, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = echo
	if keycode == KEY_SHIFT:
		event.location = KEY_LOCATION_LEFT
		event.shift_pressed = true
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])
