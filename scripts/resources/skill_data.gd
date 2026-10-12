class_name SkillData
extends Resource
## Everything that defines one skill. One .tres file per skill in
## res://data/skills/.
##
## The skill's level is not stored here: it belongs to the player's
## [SkillHolder]. This resource only says what a level is worth. Behaviour
## lives in [member skill_scene], whose root extends [Skill].

enum Activation {
	## Cast with [member input_action].
	ACTIVE,
	## Never cast by key. The skill's own script calls
	## [method SkillHolder.trigger] when its condition is met (Berserk).
	AUTOMATIC,
}

## 0 means locked.
const LOCKED_LEVEL: int = 0
const MIN_LEVEL: int = 1

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## The scene that performs the skill. Its root must extend [Skill]. Without
## one the skill still pays its cost and starts its cooldown, but does nothing.
@export var skill_scene: PackedScene

@export_group("Casting")
@export var activation: Activation = Activation.ACTIVE
## Input Map action that casts the skill. Ignored for automatic skills.
@export var input_action: StringName
## Flat HP paid per cast. Defense never reduces it. 0 is allowed (Berserk).
@export_range(0.0, 999.0, 1.0) var hp_cost: float = 0.0
## Seconds before the skill can be cast again.
@export_range(0.0, 600.0, 0.1) var cooldown: float = 1.0
## Clear the cooldown whenever a new wave starts (Berserk).
@export var resets_on_new_wave: bool = false
## No skill crits in v1.0. Kept for later updates.
@export var can_crit: bool = false

@export_group("Values")
## The skill's main number at level 1, before stats: heal, damage, distance
## or duration. What it means is up to the skill's script.
@export var base_value: float = 0.0
## Pixels. Reach or radius, for skills that have one. 0 if unused.
@export var reach: float = 0.0
## Highest level a skill point can raise it to.
@export_range(1, 10) var max_level: int = 5
## Extra main value per level above 1. 0.2 = +20% per level.
@export var value_growth_per_level: float = 0.2


## Multiplier on the main value at [param level]: 1.0 at level 1, 1.2 at
## level 2, and so on. Cost and cooldown never change with level.
func get_level_multiplier(level: int) -> float:
	var steps: int = clampi(level, MIN_LEVEL, max_level) - MIN_LEVEL
	return 1.0 + value_growth_per_level * steps


## The main value at [param level], before stats.
func get_value(level: int) -> float:
	return base_value * get_level_multiplier(level)


func is_automatic() -> bool:
	return activation == Activation.AUTOMATIC
