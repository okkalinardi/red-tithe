class_name StatConfig
extends Resource
## Every balancing constant and formula that turns primary stats into derived
## stats. This is the only place the formulas live.
##
## To rebalance, edit [code]res://data/stat_config.tres[/code] in the
## inspector. No code change is needed. Source of the numbers: the
## "Stat formulas" page of the GDD.

@export_group("Max HP (VIT)")
@export var base_max_hp: int = 100
@export var max_hp_per_vitality: int = 6

@export_group("HP regen (VIT)")
## HP per second.
@export var base_hp_regen: float = 2.0
@export var hp_regen_per_vitality: float = 0.1

@export_group("Weapon damage (STR / DEX)")
## Damage bonus per point of the weapon's scaling stat. 0.02 = +2%.
@export var weapon_damage_per_point: float = 0.02

@export_group("Defense (STR)")
## STR at which incoming damage is halved. Reduction never reaches 100%.
@export var defense_half_point: float = 50.0
## An enemy hit never deals less than this.
@export var min_damage_taken: int = 1

@export_group("Range (DEX)")
@export var range_per_dexterity: float = 0.01
## Largest bonus. 0.5 = range can reach x1.5.
@export var range_bonus_cap: float = 0.5

@export_group("Attack speed (AGI)")
@export var attack_speed_per_agility: float = 0.02
## Largest bonus. 1.0 = attack speed can reach x2.
@export var attack_speed_bonus_cap: float = 1.0

@export_group("Move speed (AGI)")
## Pixels per second.
@export var base_move_speed: float = 90.0
@export var move_speed_per_agility: float = 0.006
## Largest bonus. 0.3 = move speed can reach x1.3.
@export var move_speed_bonus_cap: float = 0.3

@export_group("Crit (LUK)")
@export_range(0.0, 1.0, 0.001) var base_crit_chance: float = 0.05
@export var crit_chance_per_luck: float = 0.015
@export var crit_damage_multiplier: float = 2.0

@export_group("Magic damage (INT)")
@export var magic_damage_per_intelligence: float = 0.03


func max_hp(vitality: int) -> int:
	return base_max_hp + max_hp_per_vitality * vitality


func hp_regen(vitality: int) -> float:
	return base_hp_regen + hp_regen_per_vitality * vitality


## [param scaling_points] is the weapon's scaling stat, already weighted
## (for example the STR/DEX average for the Dagger).
func weapon_damage_multiplier(scaling_points: float) -> float:
	return 1.0 + weapon_damage_per_point * scaling_points


## Fraction of an enemy hit that is removed, from 0.0 up to (never reaching) 1.0.
func damage_reduction(strength: int) -> float:
	if strength <= 0 or defense_half_point <= 0.0:
		return 0.0
	return strength / (strength + defense_half_point)


func range_multiplier(dexterity: int) -> float:
	return 1.0 + minf(range_per_dexterity * dexterity, range_bonus_cap)


func attack_speed_multiplier(agility: int) -> float:
	return 1.0 + minf(attack_speed_per_agility * agility, attack_speed_bonus_cap)


func move_speed(agility: int) -> float:
	return base_move_speed * (1.0 + minf(move_speed_per_agility * agility, move_speed_bonus_cap))


func crit_chance(luck: int) -> float:
	return clampf(base_crit_chance + crit_chance_per_luck * luck, 0.0, 1.0)


func magic_damage_multiplier(intelligence: int) -> float:
	return 1.0 + magic_damage_per_intelligence * intelligence
