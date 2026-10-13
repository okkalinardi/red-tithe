class_name BerserkSkill
extends Skill
## Berserk: automatic second chance. When a hit would kill the caster, they
## survive at 1 HP and deal more damage for a while.
##
## It hooks [member HealthComponent.lethal_hit_handler] as soon as it is
## learned and casts itself through [method SkillHolder.trigger], so cost and
## cooldown follow the usual rules. Duration = base value x the level
## multiplier (+20% per level). The buff and the cooldown both reset when the
## wave changes. The tint and aura are placeholders until the effect art exists.

## Multiplier on all damage dealt while Berserk lasts.
@export var damage_multiplier: float = 2.0
@export var tint: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var effect_color: Color = Color(0.86, 0.14, 0.18, 1.0)

var _buff_left: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	set_process(false)
	caster.health.lethal_hit_handler = _on_lethal_hit
	Events.wave_completed.connect(_on_wave_completed)


func _exit_tree() -> void:
	if caster != null and caster.health.lethal_hit_handler == Callable(self, &"_on_lethal_hit"):
		caster.health.lethal_hit_handler = Callable()


func _process(delta: float) -> void:
	_buff_left -= delta
	_pulse += delta
	if _buff_left <= 0.0:
		end_buff()
		return
	queue_redraw()


## Seconds the buff lasts at the current level.
func get_duration() -> float:
	return get_value()


func is_buff_active() -> bool:
	return _buff_left > 0.0


## Seconds of buff left, 0 when inactive.
func get_buff_left() -> float:
	return maxf(_buff_left, 0.0)


## Ends the buff at once. Safe to call when it is not active.
func end_buff() -> void:
	var was_active: bool = _buff_left > 0.0 or is_processing()
	_buff_left = 0.0
	set_process(false)
	if was_active:
		caster.stats.damage_buff_multiplier = 1.0
		caster.set_tint(Color.WHITE)
	queue_redraw()


func on_wave_started() -> void:
	end_buff()


func _activate() -> void:
	_buff_left = get_duration()
	_pulse = 0.0
	caster.stats.damage_buff_multiplier = damage_multiplier
	caster.set_tint(tint)
	set_process(true)
	queue_redraw()


# Called by the health component in the middle of a lethal hit. Returning
# true keeps the caster alive at 1 HP.
func _on_lethal_hit() -> bool:
	var slot: int = caster.skills.find_slot(data)
	return caster.skills.trigger(slot) == SkillHolder.CastResult.OK


func _on_wave_completed(_wave: int) -> void:
	end_buff()


func _draw() -> void:
	if _buff_left <= 0.0:
		return
	var alpha: float = 0.45 + 0.25 * sin(_pulse * TAU * 2.0)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color(effect_color, alpha), 1.5)
