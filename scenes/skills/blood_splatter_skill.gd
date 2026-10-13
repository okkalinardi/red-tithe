class_name BloodSplatterSkill
extends Skill
## Blood Splatter: damages every enemy within reach of the caster.
##
## Damage = base value x magic damage (INT) x the level multiplier (+20% per
## level). It crits only if the skill data has can_crit, which no skill has
## in v1.0. Casting with no enemy in reach is allowed; it is the player's call.
## The effect drawn here is a placeholder until the skill effect art exists.

## Seconds the placeholder effect stays on screen.
@export var effect_time: float = 0.22
@export var effect_color: Color = Color(0.86, 0.14, 0.18, 1.0)

## Replace with a seeded generator to make crits repeatable in tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _effect_left: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_effect_left -= delta
	if _effect_left <= 0.0:
		set_process(false)
	queue_redraw()


## Damage of one hit at the current level, stats and buffs, before crit.
func get_damage() -> float:
	var stats: StatBlock = caster.stats
	return data.get_value(level) * stats.magic_damage_multiplier * stats.damage_buff_multiplier


## Every enemy a cast would hit now.
func find_targets() -> Array[Enemy]:
	var origin: Vector2 = caster.global_position
	var targets: Array[Enemy] = []
	for enemy: Enemy in Enemy.active:
		if not enemy.health.is_alive():
			continue
		var gap: float = origin.distance_to(enemy.global_position) - enemy.data.hurtbox_radius
		if gap <= data.reach:
			targets.append(enemy)
	return targets


func _activate() -> void:
	var damage: float = get_damage()
	# Collected first: a kill despawns the enemy and changes Enemy.active.
	for enemy: Enemy in find_targets():
		var is_crit: bool = data.can_crit and rng.randf() < caster.stats.crit_chance
		var dealt: float = damage * caster.stats.crit_damage_multiplier if is_crit else damage
		enemy.hurtbox.take_hit(dealt, is_crit)
	_effect_left = effect_time
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _effect_left <= 0.0:
		return
	var t: float = clampf(_effect_left / effect_time, 0.0, 1.0)
	var radius: float = data.reach * lerpf(1.0, 0.6, t)
	draw_circle(Vector2.ZERO, radius, Color(effect_color, 0.35 * t))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(effect_color, t), 1.5)
