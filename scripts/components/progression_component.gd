class_name ProgressionComponent
extends Node
## A character's level, XP and unspent points.
##
## XP comes in through [method add_xp]. Each level gained adds stat points
## and skill points, which the level-up screen spends through
## [method spend_stat_point] and [method spend_skill_point].
## [signal Events.player_leveled_up] is emitted for every level gained.

signal xp_changed(xp: int, xp_required: int)
signal leveled_up(level: int)
signal points_changed(stat_points: int, skill_points: int)

const _DEFAULT_CONFIG: ProgressionConfig = preload("res://data/progression.tres")

## The XP curve and rewards. Falls back to the project-wide config.
@export var config: ProgressionConfig = _DEFAULT_CONFIG

var level: int = 1
## XP gathered towards the next level.
var xp: int = 0
var stat_points: int = 0
var skill_points: int = 0

var _stats: StatBlock


## [param stats] is where spent stat points go. Also resets to level 1.
func setup(stats: StatBlock) -> void:
	_stats = stats
	reset()


## Back to level 1 with the starting points. For the start of a run.
func reset() -> void:
	level = 1
	xp = 0
	stat_points = config.starting_stat_points
	skill_points = config.starting_skill_points
	xp_changed.emit(xp, get_xp_required())
	points_changed.emit(stat_points, skill_points)


## Adds XP and levels up as many times as it pays for. XP beyond a level
## carries over to the next one.
func add_xp(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return
	xp += amount
	while not is_max_level() and xp >= get_xp_required():
		xp -= get_xp_required()
		_level_up()
	if is_max_level():
		xp = 0
	xp_changed.emit(xp, get_xp_required())


## XP needed to finish the current level.
func get_xp_required() -> int:
	return config.xp_required(level)


func is_max_level() -> bool:
	return config.max_level > 0 and level >= config.max_level


## Puts one unspent stat point into [param stat]. Returns false if there is
## none to spend.
func spend_stat_point(stat: StatBlock.Stat) -> bool:
	if stat_points <= 0 or _stats == null:
		return false
	stat_points -= 1
	_stats.add_points(stat)
	points_changed.emit(stat_points, skill_points)
	return true


## Uses up one unspent skill point. Returns false if there is none. What the
## point buys is decided by the caller (the skill system).
func spend_skill_point() -> bool:
	if skill_points <= 0:
		return false
	skill_points -= 1
	points_changed.emit(stat_points, skill_points)
	return true


func _level_up() -> void:
	level += 1
	stat_points += config.stat_points_per_level
	skill_points += config.skill_points_per_level
	leveled_up.emit(level)
	points_changed.emit(stat_points, skill_points)
	Events.player_leveled_up.emit(level)
