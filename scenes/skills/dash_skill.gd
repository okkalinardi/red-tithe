class_name DashSkill
extends Skill
## Dash: a quick burst of movement. No invincibility.
##
## Goes the way the movement keys point; standing still, it goes towards the
## mouse. Distance = (base value + AGI) x the level multiplier (+20% per
## level). Walls stop it. The trail drawn here is a placeholder until the
## skill effect art exists.

## Seconds the dash takes. Shorter feels snappier.
@export var dash_time: float = 0.12
## Seconds the placeholder trail stays on screen after the dash.
@export var trail_time: float = 0.18
@export var effect_color: Color = Color(0.86, 0.14, 0.18, 1.0)

var _effect_left: float = 0.0
var _trail_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_effect_left -= delta
	if _effect_left <= 0.0:
		set_process(false)
	queue_redraw()


## Pixels one dash covers in open ground, at the current level and stats.
func get_distance() -> float:
	return (data.base_value + caster.stats.agility) * data.get_level_multiplier(level)


## Unit vector the next dash would take.
func get_direction() -> Vector2:
	if not caster.move_direction.is_zero_approx():
		return caster.move_direction
	return caster.aim_direction


func _activate() -> void:
	_trail_start = caster.global_position
	caster.dash(get_direction(), get_distance(), dash_time)
	_effect_left = dash_time + trail_time
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _effect_left <= 0.0:
		return
	var t: float = clampf(_effect_left / (dash_time + trail_time), 0.0, 1.0)
	var start: Vector2 = to_local(_trail_start)
	draw_line(start, Vector2.ZERO, Color(effect_color, 0.6 * t), 4.0 * t + 1.0)
	draw_circle(start, 3.0 * t, Color(effect_color, 0.5 * t))
