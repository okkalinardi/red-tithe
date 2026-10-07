class_name ProgressionConfig
extends Resource
## The XP curve and what a level is worth. Edit
## [code]res://data/progression.tres[/code] in the inspector to rebalance.
##
## XP needed to go from level L to L + 1:
## [code](first_level_xp + xp_increase_per_level x (L - 1)) x xp_growth ^ (L - 1)[/code]

@export_group("XP curve")
## XP needed to go from level 1 to level 2.
@export var first_level_xp: int = 10
## Added to the requirement for every level after the first.
@export var xp_increase_per_level: int = 9
## Multiplies the requirement once per level. 1.0 keeps the curve a straight
## line; 1.1 makes every level 10% more expensive than the line says.
@export var xp_growth: float = 1.0
## The highest level. 0 means no limit.
@export var max_level: int = 0

@export_group("Rewards per level")
@export var stat_points_per_level: int = 5
@export var skill_points_per_level: int = 1

@export_group("At the start of a run")
@export var starting_stat_points: int = 0
@export var starting_skill_points: int = 0


## XP needed to go from [param level] to the next one. Always at least 1.
func xp_required(level: int) -> int:
	var steps: int = maxi(level - 1, 0)
	var on_the_line: float = first_level_xp + xp_increase_per_level * steps
	return maxi(roundi(on_the_line * pow(xp_growth, steps)), 1)


## Total XP needed to reach [param level] from level 1.
func total_xp_for_level(level: int) -> int:
	var total: int = 0
	for current: int in range(1, level):
		total += xp_required(current)
	return total
