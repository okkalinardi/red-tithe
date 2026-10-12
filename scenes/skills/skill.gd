class_name Skill
extends Node2D
## The behaviour of one learned skill. [SkillHolder] creates it from
## [member SkillData.skill_scene] when the skill is unlocked, and owns cost,
## cooldown and input. A concrete skill only says when it can fire and what
## it does:
## [codeblock]
## func can_activate() -> bool:
##     return _find_target() != null      # Consume: nothing in reach, no cast
##
## func _activate() -> void:
##     caster.health.heal(get_value() + caster.stats.strength + caster.stats.vitality)
## [/codeblock]
## The node sits at the player's position, so effects can be added as children.

var data: SkillData
var caster: Player
## 1 to [member SkillData.max_level].
var level: int = SkillData.MIN_LEVEL


func setup(skill_data: SkillData, skill_caster: Player, start_level: int) -> void:
	data = skill_data
	caster = skill_caster
	level = start_level


## Called by [SkillHolder] when a skill point raises the level.
func set_level(new_level: int) -> void:
	level = new_level
	_on_level_changed()


## The main value at the current level, before stats.
func get_value() -> float:
	return data.get_value(level)


## Override to refuse a cast that would be wasted (for example no target in
## reach). Checked before any HP is paid.
func can_activate() -> bool:
	return true


## Called by [SkillHolder] after the cost has been paid.
func activate() -> void:
	_activate()


## Called at the start of every wave. Override to end effects that last
## until the wave changes.
func on_wave_started() -> void:
	pass


## Override in a concrete skill.
func _activate() -> void:
	pass


## Override to react to an upgrade.
func _on_level_changed() -> void:
	pass
