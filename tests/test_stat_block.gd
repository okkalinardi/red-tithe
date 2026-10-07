extends Node
## Regression test for the stat formulas. Run this scene (F6) and read the
## Output panel. It uses the default constants written in stat_config.gd, not
## data/stat_config.tres, so editing the balance data does not break it.

var _failures: int = 0
var _checks: int = 0
var _signal_count: int = 0


func _ready() -> void:
	_test_zero_stats()
	_test_table_values()
	_test_caps()
	_test_weapon_damage()
	_test_defense()
	_test_signal_and_api()
	_test_example_builds()
	var summary: String = "StatBlock tests: %d checks, %d failed" % [_checks, _failures]
	print(summary)
	var label := Label.new()
	label.text = summary
	add_child(label)


func _new_block() -> StatBlock:
	var block := StatBlock.new()
	block.config = StatConfig.new()
	return block


func _check(what: String, actual: float, expected: float) -> void:
	_checks += 1
	if absf(actual - expected) > 0.001:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _test_zero_stats() -> void:
	var s: StatBlock = _new_block()
	_check("max_hp at 0", s.max_hp, 100)
	_check("hp_regen at 0", s.hp_regen, 2.0)
	_check("damage_reduction at 0", s.damage_reduction, 0.0)
	_check("range at 0", s.range_multiplier, 1.0)
	_check("attack speed at 0", s.attack_speed_multiplier, 1.0)
	_check("move_speed at 0", s.move_speed, 90.0)
	_check("crit at 0", s.crit_chance, 0.05)
	_check("crit damage", s.crit_damage_multiplier, 2.0)
	_check("magic at 0", s.magic_damage_multiplier, 1.0)


func _test_table_values() -> void:
	var s: StatBlock = _new_block()
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		s.set_primary(stat, 25)
	_check("max_hp at 25", s.max_hp, 250)
	_check("hp_regen at 25", s.hp_regen, 4.5)
	_check("damage_reduction at 25", s.damage_reduction, 1.0 / 3.0)
	_check("range at 25", s.range_multiplier, 1.25)
	_check("attack speed at 25", s.attack_speed_multiplier, 1.5)
	_check("move_speed at 25", s.move_speed, 103.5)
	_check("crit at 25", s.crit_chance, 0.425)
	_check("magic at 25", s.magic_damage_multiplier, 1.75)
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		s.set_primary(stat, 50)
	_check("max_hp at 50", s.max_hp, 400)
	_check("hp_regen at 50", s.hp_regen, 7.0)
	_check("damage_reduction at 50", s.damage_reduction, 0.5)
	_check("range at 50", s.range_multiplier, 1.5)
	_check("attack speed at 50", s.attack_speed_multiplier, 2.0)
	_check("move_speed at 50", s.move_speed, 117.0)
	_check("crit at 50", s.crit_chance, 0.8)
	_check("magic at 50", s.magic_damage_multiplier, 2.5)


func _test_caps() -> void:
	var s: StatBlock = _new_block()
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		s.set_primary(stat, 200)
	_check("range cap", s.range_multiplier, 1.5)
	_check("attack speed cap", s.attack_speed_multiplier, 2.0)
	_check("move_speed cap", s.move_speed, 117.0)
	_check("crit cap", s.crit_chance, 1.0)
	_check("damage_reduction below 1", float(s.damage_reduction < 1.0), 1.0)
	s.strength = -5
	_check("negative stat clamps to 0", s.strength, 0)


func _test_weapon_damage() -> void:
	var s: StatBlock = _new_block()
	s.strength = 20
	s.dexterity = 40
	_check("sword uses STR", s.weapon_damage_multiplier(1.0, 0.0), 1.4)
	_check("bow uses DEX", s.weapon_damage_multiplier(0.0, 1.0), 1.8)
	_check("dagger uses the average", s.weapon_damage_multiplier(0.5, 0.5), 1.6)


func _test_defense() -> void:
	var s: StatBlock = _new_block()
	_check("no defense", s.apply_defense(20.0), 20)
	s.strength = 50
	_check("half damage at STR 50", s.apply_defense(20.0), 10)
	_check("minimum 1 damage", s.apply_defense(1.0), 1)
	_check("zero damage stays zero", s.apply_defense(0.0), 0)


func _test_signal_and_api() -> void:
	var s: StatBlock = _new_block()
	s.changed.connect(func() -> void: _signal_count += 1)
	s.add_points(StatBlock.Stat.VIT, 5)
	_check("changed emitted once per change", _signal_count, 1)
	_check("add_points", s.get_primary(StatBlock.Stat.VIT), 5)
	_check("derived follows add_points", s.max_hp, 130)
	s.add_points(StatBlock.Stat.LUK)
	_check("add_points default is 1", s.luck, 1)
	var default_block := StatBlock.new()
	_check("default config is loaded", float(default_block.config != null), 1.0)
	default_block.config = null
	_check("null config falls back", float(default_block.config != null), 1.0)
	var copy: StatBlock = s.duplicate()
	copy.vitality = 30
	_check("duplicate is independent", s.vitality, 5)
	_check("duplicate recalculates", copy.max_hp, 280)


# Rows from the "Sanity check" table of the Stat formulas page.
func _test_example_builds() -> void:
	var bruiser: StatBlock = _new_block()
	bruiser.strength = 25
	bruiser.agility = 15
	bruiser.vitality = 15
	_check("bruiser max_hp", bruiser.max_hp, 190)
	_check("bruiser regen", bruiser.hp_regen, 3.5)
	_check("bruiser move", bruiser.move_speed, 98.1)
	var weapon_output: float = (
		bruiser.weapon_damage_multiplier(1.0, 0.0)
		* bruiser.attack_speed_multiplier
		* (1.0 + bruiser.crit_chance * (bruiser.crit_damage_multiplier - 1.0))
	)
	_check("bruiser weapon output", snappedf(weapon_output, 0.01), 2.05)
	var caster: StatBlock = _new_block()
	caster.intelligence = 20
	caster.vitality = 30
	caster.luck = 5
	_check("caster max_hp", caster.max_hp, 280)
	_check("caster regen", caster.hp_regen, 5.0)
	_check("caster magic", caster.magic_damage_multiplier, 1.6)
	_check("caster crit", caster.crit_chance, 0.125)
