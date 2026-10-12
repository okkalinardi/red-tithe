class_name StatBlock
extends Resource
## The six primary stats of a character and the derived stats calculated
## from them.
##
## Derived values are recalculated whenever a primary stat changes, and the
## built-in [signal Resource.changed] signal is emitted so UI can refresh:
## [codeblock]
## stats.changed.connect(_on_stats_changed)
## stats.add_points(StatBlock.Stat.VIT, 5)
## [/codeblock]
## Resources loaded from disk are shared. A character that changes its stats
## at runtime must own a copy: [code]stats = stats.duplicate()[/code].

enum Stat { STR, DEX, AGI, VIT, INT, LUK }

const _DEFAULT_CONFIG: StatConfig = preload("res://data/stat_config.tres")

## Balancing constants and formulas. Falls back to the project-wide config.
@export var config: StatConfig = _DEFAULT_CONFIG:
	set(value):
		config = value if value != null else _DEFAULT_CONFIG
		recalculate()

@export_group("Primary stats")
@export_range(0, 999) var strength: int = 0:
	set(value):
		strength = maxi(value, 0)
		recalculate()
@export_range(0, 999) var dexterity: int = 0:
	set(value):
		dexterity = maxi(value, 0)
		recalculate()
@export_range(0, 999) var agility: int = 0:
	set(value):
		agility = maxi(value, 0)
		recalculate()
@export_range(0, 999) var vitality: int = 0:
	set(value):
		vitality = maxi(value, 0)
		recalculate()
@export_range(0, 999) var intelligence: int = 0:
	set(value):
		intelligence = maxi(value, 0)
		recalculate()
@export_range(0, 999) var luck: int = 0:
	set(value):
		luck = maxi(value, 0)
		recalculate()

# Derived stats. Read these; never assign them. They are not saved.
var max_hp: int
## HP per second.
var hp_regen: float
## Fraction of an enemy hit that is removed, 0.0 to below 1.0.
var damage_reduction: float
var range_multiplier: float
## Divide a weapon's base cooldown by this.
var attack_speed_multiplier: float
## Pixels per second.
var move_speed: float
## 0.0 to 1.0.
var crit_chance: float
var crit_damage_multiplier: float
var magic_damage_multiplier: float


func _init() -> void:
	recalculate()


func get_primary(stat: Stat) -> int:
	match stat:
		Stat.STR:
			return strength
		Stat.DEX:
			return dexterity
		Stat.AGI:
			return agility
		Stat.VIT:
			return vitality
		Stat.INT:
			return intelligence
		Stat.LUK:
			return luck
	push_error("Unknown stat: %d" % stat)
	return 0


func set_primary(stat: Stat, value: int) -> void:
	match stat:
		Stat.STR:
			strength = value
		Stat.DEX:
			dexterity = value
		Stat.AGI:
			agility = value
		Stat.VIT:
			vitality = value
		Stat.INT:
			intelligence = value
		Stat.LUK:
			luck = value
		_:
			push_error("Unknown stat: %d" % stat)


func add_points(stat: Stat, amount: int = 1) -> void:
	set_primary(stat, get_primary(stat) + amount)


## Damage multiplier for a weapon. The weights say how much each stat counts:
## Sword (1, 0), Bow (0, 1), Dagger (0.5, 0.5).
func weapon_damage_multiplier(strength_weight: float, dexterity_weight: float) -> float:
	var scaling_points: float = strength * strength_weight + dexterity * dexterity_weight
	return config.weapon_damage_multiplier(scaling_points)


## Damage actually taken from an enemy hit of [param raw_damage].
## Do not use this for skill HP costs; Defense never reduces those.
func apply_defense(raw_damage: float) -> int:
	if raw_damage <= 0.0:
		return 0
	return maxi(roundi(raw_damage * (1.0 - damage_reduction)), config.min_damage_taken)


## Recomputes every derived stat and emits [signal Resource.changed].
## Called automatically when a primary stat or the config is assigned. Call it
## by hand only after editing values inside [member config] at runtime.
func recalculate() -> void:
	max_hp = config.max_hp(vitality)
	hp_regen = config.hp_regen(vitality)
	damage_reduction = config.damage_reduction(strength)
	range_multiplier = config.range_multiplier(dexterity)
	attack_speed_multiplier = config.attack_speed_multiplier(agility)
	move_speed = config.move_speed(agility)
	crit_chance = config.crit_chance(luck)
	crit_damage_multiplier = config.crit_damage_multiplier
	magic_damage_multiplier = config.magic_damage_multiplier(intelligence)
	emit_changed()
