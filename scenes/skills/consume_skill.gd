class_name ConsumeSkill
extends Skill
## Consume: instantly kills the nearest enemy within reach and heals the
## caster. Bosses are skipped. With nothing in reach the cast is refused, so
## no HP is wasted.
##
## Heal = (base value + STR + VIT) x the level multiplier (+20% per level).
## The kill counts as a normal kill: XP, gold and the kill counter all apply.
## The effect drawn here is a placeholder until the skill effect art exists.

## Seconds the placeholder effect stays on screen.
@export var effect_time: float = 0.25
@export var effect_color: Color = Color(0.86, 0.14, 0.18, 1.0)

var _effect_left: float = 0.0
var _effect_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_effect_left -= delta
	if _effect_left <= 0.0:
		set_process(false)
	queue_redraw()


## HP restored by one cast at the current level and stats.
func get_heal() -> float:
	var stats: StatBlock = caster.stats
	return (data.base_value + stats.strength + stats.vitality) * data.get_level_multiplier(level)


## The enemy a cast would consume now, or null.
func find_target() -> Enemy:
	var origin: Vector2 = caster.global_position
	var best: Enemy = null
	var best_gap: float = INF
	for enemy: Enemy in Enemy.active:
		if enemy.data.is_boss or not enemy.health.is_alive():
			continue
		# Measured to the edge of the enemy's hurtbox, so big enemies are not
		# harder to reach than small ones.
		var gap: float = origin.distance_to(enemy.global_position) - enemy.data.hurtbox_radius
		if gap <= data.reach and gap < best_gap:
			best = enemy
			best_gap = gap
	return best


func can_activate() -> bool:
	return find_target() != null


func _activate() -> void:
	var target: Enemy = find_target()
	if target == null:
		return
	_effect_target = target.global_position
	target.health.kill()
	caster.health.heal(get_heal())
	_effect_left = effect_time
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _effect_left <= 0.0:
		return
	var t: float = clampf(_effect_left / effect_time, 0.0, 1.0)
	var color := Color(effect_color, t)
	var target: Vector2 = to_local(_effect_target)
	# Blood drawn from the victim to the caster.
	draw_line(target, Vector2.ZERO, color, 2.0)
	draw_circle(target, 6.0 * t, color)
	draw_arc(Vector2.ZERO, 10.0 * (1.0 - t) + 4.0, 0.0, TAU, 16, color, 1.0)
