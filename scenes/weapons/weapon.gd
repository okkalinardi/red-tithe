class_name Weapon
extends Node2D
## One held weapon. Handles the attack timer, stat scaling and crit rolls.
##
## A concrete weapon (Sword, Bow) extends this and overrides [method _attack]
## to do the actual hitting, calling [method roll_damage] for each enemy it
## hits. [WeaponHolder] owns the weapons and ticks them.

## Emitted every time the weapon attacks. For sound and effects.
signal attacked(direction: Vector2)

## The result of one damage roll.
class DamageRoll:
	extends RefCounted
	var damage: float = 0.0
	var is_crit: bool = false

const _MIN_COOLDOWN: float = 0.05

var data: WeaponData
## 1 to 10. Raised by buying a duplicate.
var tier: int = WeaponData.MIN_TIER
## Replace with a seeded generator to make crits repeatable in tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _stats: StatBlock
var _cooldown_left: float = 0.0


func setup(weapon_data: WeaponData, stats: StatBlock, start_tier: int = WeaponData.MIN_TIER) -> void:
	data = weapon_data
	_stats = stats
	tier = clampi(start_tier, WeaponData.MIN_TIER, WeaponData.MAX_TIER)


## Advances the attack timer and attacks towards [param aim_direction] when
## it runs out. Called by [WeaponHolder] every physics frame.
func tick(delta: float, aim_direction: Vector2, can_fire: bool) -> void:
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	if not can_fire:
		# Stay ready, so the weapon fires the moment firing is allowed again.
		_cooldown_left = 0.0
		return
	_attack(aim_direction)
	attacked.emit(aim_direction)
	# Adding instead of assigning keeps the leftover time, so the fire rate
	# does not drift with the frame rate.
	_cooldown_left = maxf(_cooldown_left + get_cooldown(), 0.0)


## Seconds between attacks, after attack speed from stats.
func get_cooldown() -> float:
	return maxf(data.base_cooldown / _stats.attack_speed_multiplier, _MIN_COOLDOWN)


## Pixels, after range from stats.
func get_range() -> float:
	return data.base_range * _stats.range_multiplier


## Damage of a non-critical hit, after tier and stats.
func get_damage() -> float:
	return data.get_damage(tier) * _stats.weapon_damage_multiplier(
		data.strength_weight, data.dexterity_weight
	)


## Rolls the damage for one hit, including the crit roll. Call once per
## enemy hit, so each enemy gets its own crit chance.
func roll_damage() -> DamageRoll:
	var roll := DamageRoll.new()
	roll.is_crit = rng.randf() < _stats.crit_chance
	roll.damage = get_damage()
	if roll.is_crit:
		roll.damage *= _stats.crit_damage_multiplier
	return roll


func can_upgrade() -> bool:
	return tier < WeaponData.MAX_TIER


## Raises the tier by one. Returns false at the maximum tier.
func upgrade() -> bool:
	if not can_upgrade():
		return false
	tier += 1
	return true


## Override in a concrete weapon. [param _direction] is a unit vector.
func _attack(_direction: Vector2) -> void:
	pass
