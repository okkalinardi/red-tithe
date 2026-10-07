extends Node
## Regression test for WeaponData, Weapon, WeaponHolder and the player wiring.
## Run this scene (F6) and read the Output panel. Most of it simulates time by
## ticking weapons by hand.

const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _STEP: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0
var _attack_count: int = 0
var _last_direction: Vector2 = Vector2.ZERO
var _changed_count: int = 0


func _ready() -> void:
	_test_weapon_data()
	_test_fire_rate()
	_test_damage_and_range()
	_test_crit()
	_test_holder_slots()
	_test_holder_firing()
	await _test_player_wiring()
	print("Weapon system tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _new_stats() -> StatBlock:
	var stats := StatBlock.new()
	stats.config = StatConfig.new()
	return stats


func _new_data(id: StringName, damage: float = 10.0, cooldown: float = 0.5) -> WeaponData:
	var data := WeaponData.new()
	data.id = id
	data.base_damage = damage
	data.base_cooldown = cooldown
	data.base_range = 40.0
	return data


func _new_weapon(data: WeaponData, stats: StatBlock, tier: int = 1) -> Weapon:
	var weapon := Weapon.new()
	weapon.setup(data, stats, tier)
	weapon.rng.seed = 12345
	_attack_count = 0
	weapon.attacked.connect(_on_attacked)
	add_child(weapon)
	return weapon


func _new_holder(stats: StatBlock) -> WeaponHolder:
	var holder := WeaponHolder.new()
	add_child(holder)
	# The test advances time itself.
	holder.set_physics_process(false)
	holder.setup(stats)
	_changed_count = 0
	holder.weapons_changed.connect(func() -> void: _changed_count += 1)
	return holder


func _on_attacked(direction: Vector2) -> void:
	_attack_count += 1
	_last_direction = direction


func _tick_weapon(weapon: Weapon, seconds: float, direction: Vector2 = Vector2.RIGHT) -> void:
	for i: int in roundi(seconds / _STEP):
		weapon.tick(_STEP, direction, true)


func _tick_holder(holder: WeaponHolder, seconds: float) -> void:
	for i: int in roundi(seconds / _STEP):
		holder._physics_process(_STEP)


func _test_weapon_data() -> void:
	var data: WeaponData = _new_data(&"sword")
	_check("tier 1 damage is the base", data.get_damage(1), 10.0)
	_check("tier 2 damage", data.get_damage(2), 12.0)
	_check("tier 10 damage", data.get_damage(10), 28.0)
	_check("tier below 1 clamps", data.get_damage(0), 10.0)
	_check("tier above 10 clamps", data.get_damage(99), 28.0)


func _test_fire_rate() -> void:
	var stats: StatBlock = _new_stats()
	var weapon: Weapon = _new_weapon(_new_data(&"sword"), stats)
	weapon.tick(_STEP, Vector2.DOWN, true)
	_check("fires on the first frame", _attack_count, 1)
	_check("fires along the aim", _last_direction.distance_to(Vector2.DOWN), 0.0)
	_attack_count = 0
	_tick_weapon(weapon, 10.0)
	_check("2 attacks per second at 0.5 s cooldown", _attack_count, 20, 1.0)
	stats.agility = 50
	_check("AGI 50 halves the cooldown", weapon.get_cooldown(), 0.25)
	_attack_count = 0
	_tick_weapon(weapon, 10.0)
	_check("4 attacks per second at AGI 50", _attack_count, 40, 1.0)
	_attack_count = 0
	for i: int in 120:
		weapon.tick(_STEP, Vector2.RIGHT, false)
	_check("does not fire when firing is off", _attack_count, 0)
	weapon.tick(_STEP, Vector2.RIGHT, true)
	_check("fires at once when firing is back on", _attack_count, 1)


func _test_damage_and_range() -> void:
	var stats: StatBlock = _new_stats()
	stats.strength = 25
	stats.dexterity = 50
	var sword: Weapon = _new_weapon(_new_data(&"sword"), stats)
	_check("sword scales with STR", sword.get_damage(), 15.0)
	var bow_data: WeaponData = _new_data(&"bow")
	bow_data.strength_weight = 0.0
	bow_data.dexterity_weight = 1.0
	var bow: Weapon = _new_weapon(bow_data, stats)
	_check("bow scales with DEX", bow.get_damage(), 20.0)
	var dagger_data: WeaponData = _new_data(&"dagger")
	dagger_data.strength_weight = 0.5
	dagger_data.dexterity_weight = 0.5
	var dagger: Weapon = _new_weapon(dagger_data, stats)
	_check("dagger scales with the average", dagger.get_damage(), 17.5)
	var tiered: Weapon = _new_weapon(_new_data(&"sword"), stats, 5)
	_check("tier and stats multiply", tiered.get_damage(), 27.0)
	_check("range scales with DEX", sword.get_range(), 60.0)
	stats.dexterity = 0
	_check("base range at DEX 0", sword.get_range(), 40.0)
	_check("upgrade raises the tier", float(tiered.upgrade()), 1.0)
	_check("tier after upgrade", tiered.tier, 6)
	var maxed: Weapon = _new_weapon(_new_data(&"sword"), stats, 10)
	_check("no upgrade past tier 10", float(maxed.upgrade()), 0.0)
	_check("tier stays 10", maxed.tier, 10)


func _test_crit() -> void:
	var never: StatBlock = _new_stats()
	never.config.base_crit_chance = 0.0
	never.recalculate()
	var weapon: Weapon = _new_weapon(_new_data(&"sword"), never)
	var crits: int = 0
	for i: int in 200:
		if weapon.roll_damage().is_crit:
			crits += 1
	_check("0% crit never crits", crits, 0)
	_check("non-crit damage", weapon.roll_damage().damage, 10.0)

	var always: StatBlock = _new_stats()
	always.luck = 200
	weapon = _new_weapon(_new_data(&"sword"), always)
	var roll: Weapon.DamageRoll = weapon.roll_damage()
	_check("100% crit always crits", float(roll.is_crit), 1.0)
	_check("crit doubles the damage", roll.damage, 20.0)

	var half: StatBlock = _new_stats()
	half.luck = 30
	weapon = _new_weapon(_new_data(&"sword"), half)
	crits = 0
	var total: float = 0.0
	for i: int in 4000:
		roll = weapon.roll_damage()
		total += roll.damage
		if roll.is_crit:
			crits += 1
	_check("LUK 30 crits about half the time", crits / 4000.0, 0.5, 0.03)
	_check("average damage is about x1.5", total / 4000.0, 15.0, 0.3)


func _test_holder_slots() -> void:
	var holder: WeaponHolder = _new_holder(_new_stats())
	var sword: WeaponData = _new_data(&"sword")
	var bow: WeaponData = _new_data(&"bow")
	var dagger: WeaponData = _new_data(&"dagger")
	_check("two slots", WeaponHolder.SLOT_COUNT, 2)
	_check("starts empty", float(holder.get_weapon(0) == null and holder.get_weapon(1) == null), 1.0)
	_check("first weapon is accepted", float(holder.add_weapon(sword)), 1.0)
	_check("it goes to slot 0", holder.find_slot(sword), 0)
	_check("second weapon is accepted", float(holder.add_weapon(bow)), 1.0)
	_check("it goes to slot 1", holder.find_slot(bow), 1)
	_check("no free slot left", holder.get_free_slot(), -1)
	_check("a third weapon is refused", float(holder.add_weapon(dagger)), 0.0)
	_check("weapons_changed emitted per change", _changed_count, 2)
	_check("a duplicate is accepted", float(holder.add_weapon(sword)), 1.0)
	_check("the duplicate raised the tier", holder.get_weapon(0).tier, 2)
	_check("the other weapon is untouched", holder.get_weapon(1).tier, 1)
	_check("weapons_changed emitted on upgrade", _changed_count, 3)
	for i: int in 20:
		holder.add_weapon(sword)
	_check("tier stops at 10", holder.get_weapon(0).tier, 10)
	_check("a duplicate at tier 10 is refused", float(holder.add_weapon(sword)), 0.0)
	holder.unequip(1)
	_check("unequip frees the slot", holder.get_free_slot(), 1)
	_check("the new weapon fits now", float(holder.add_weapon(dagger)), 1.0)
	holder.equip(0, bow, 4)
	_check("equip replaces a slot", float(holder.get_weapon(0).data == bow), 1.0)
	_check("equip sets the tier", holder.get_weapon(0).tier, 4)

	var preset := WeaponHolder.new()
	preset.starting_weapons = [sword, bow]
	add_child(preset)
	preset.set_physics_process(false)
	preset.setup(_new_stats())
	_check("starting weapons are equipped", float(preset.find_slot(sword) == 0 and preset.find_slot(bow) == 1), 1.0)


func _test_holder_firing() -> void:
	var holder: WeaponHolder = _new_holder(_new_stats())
	holder.add_weapon(_new_data(&"sword", 10.0, 0.5))
	holder.add_weapon(_new_data(&"bow", 10.0, 1.0))
	_attack_count = 0
	holder.get_weapon(0).attacked.connect(_on_attacked)
	holder.get_weapon(1).attacked.connect(_on_attacked)
	holder.aim_direction = Vector2.UP
	_tick_holder(holder, 10.0)
	_check("both slots fire at their own rate", _attack_count, 30, 2.0)
	_check("holder passes its aim to the weapons", _last_direction.distance_to(Vector2.UP), 0.0)
	holder.firing_enabled = false
	_attack_count = 0
	_tick_holder(holder, 3.0)
	_check("holder can hold fire", _attack_count, 0)


func _test_player_wiring() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	# Whatever the player starts with is replaced by a plain test weapon.
	var weapon: Weapon = player.weapons.equip(0, _new_data(&"test", 10.0, 0.1))
	player.weapons.unequip(1)
	_check("player accepts a weapon", float(player.weapons.get_weapon(0) == weapon), 1.0)
	player.stats.strength = 50
	_check("weapon uses the player's stats", weapon.get_damage(), 20.0)
	_attack_count = 0
	weapon.attacked.connect(_on_attacked)
	for i: int in 30:
		await get_tree().physics_frame
	_check("player weapon fires by itself", float(_attack_count >= 4), 1.0)
	_check("it fires along the player's aim", float(_last_direction.dot(player.aim_direction) > 0.99), 1.0)
	player.health.take_damage(99999.0)
	await get_tree().physics_frame
	_attack_count = 0
	for i: int in 30:
		await get_tree().physics_frame
	_check("a dead player stops firing", _attack_count, 0)
	player.queue_free()
