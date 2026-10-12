class_name LevelUpScreen
extends CanvasLayer
## Spend unspent stat points between waves.
##
## [method open] pauses the game and shows the six primary stats. Plus and
## minus buttons build up a plan; the right-hand list previews every derived
## stat with the plan applied. Nothing is spent until Done, so Reset can undo
## a misclick. Points left unspent are kept for next time.
## Skill points are not spent here yet (Sprint 2).

signal closed

## Shown next to each primary stat. Order follows [enum StatBlock.Stat].
@export var stat_names: PackedStringArray = PackedStringArray(["STR", "DEX", "AGI", "VIT", "INT", "LUK"])
## Hover text for each primary stat. Order follows [enum StatBlock.Stat].
@export var stat_hints: PackedStringArray = PackedStringArray([
	"Sword damage, defense",
	"Bow damage, range",
	"Attack speed, move speed",
	"Max HP, HP regen",
	"Magic damage (skills)",
	"Crit chance",
])
## Colour of a derived value that the plan would change.
@export var changed_color: Color = Color(0.45, 1.0, 0.45)

var _player: Player
var _planned: Dictionary[StatBlock.Stat, int] = {}
var _preview: StatBlock
var _value_labels: Dictionary[StatBlock.Stat, Label] = {}
var _plus_buttons: Dictionary[StatBlock.Stat, Button] = {}
var _minus_buttons: Dictionary[StatBlock.Stat, Button] = {}
var _derived_labels: Array[Label] = []

@onready var _points_label: Label = %PointsLabel
@onready var _stat_grid: GridContainer = %StatGrid
@onready var _derived_list: VBoxContainer = %DerivedList
@onready var _reset_button: Button = %ResetButton
@onready var _done_button: Button = %DoneButton


func _ready() -> void:
	# Runs while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_stat_rows()
	_reset_button.pressed.connect(reset_plan)
	_done_button.pressed.connect(confirm)


## Shows the screen for [param player] and pauses the game.
func open(player: Player) -> void:
	_player = player
	_planned.clear()
	_refresh()
	visible = true
	get_tree().paused = true
	_done_button.grab_focus()


func is_open() -> bool:
	return visible


## Adds one point to the plan for [param stat]. Returns false if no point is left.
func plan_point(stat: StatBlock.Stat) -> bool:
	if get_points_left() <= 0:
		return false
	_planned[stat] = _planned.get(stat, 0) + 1
	_refresh()
	return true


## Takes one point back out of the plan for [param stat].
func unplan_point(stat: StatBlock.Stat) -> bool:
	if _planned.get(stat, 0) <= 0:
		return false
	_planned[stat] -= 1
	_refresh()
	return true


func reset_plan() -> void:
	_planned.clear()
	_refresh()


## Points not yet in the plan.
func get_points_left() -> int:
	var planned_total: int = 0
	for stat: StatBlock.Stat in _planned:
		planned_total += _planned[stat]
	return _player.progression.stat_points - planned_total


## Spends the plan, closes the screen and unpauses the game.
func confirm() -> void:
	for stat: StatBlock.Stat in _planned:
		for i: int in _planned[stat]:
			_player.progression.spend_stat_point(stat)
	_planned.clear()
	visible = false
	get_tree().paused = false
	closed.emit()


func _build_stat_rows() -> void:
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		var name_label := Label.new()
		name_label.text = stat_names[stat]
		name_label.tooltip_text = stat_hints[stat]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(16, 14)
		minus.pressed.connect(unplan_point.bind(stat))
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(16, 14)
		plus.tooltip_text = stat_hints[stat]
		plus.pressed.connect(plan_point.bind(stat))
		for control: Control in [name_label, value_label, minus, plus]:
			_stat_grid.add_child(control)
		_value_labels[stat] = value_label
		_minus_buttons[stat] = minus
		_plus_buttons[stat] = plus
	for i: int in _get_derived_rows(StatBlock.new()).size():
		var label := Label.new()
		_derived_list.add_child(label)
		_derived_labels.append(label)


func _refresh() -> void:
	if _player == null:
		return
	var stats: StatBlock = _player.stats
	_preview = stats.duplicate() as StatBlock
	for stat: StatBlock.Stat in _planned:
		_preview.add_points(stat, _planned[stat])

	var left: int = get_points_left()
	_points_label.text = "%d point%s to spend" % [left, "" if left == 1 else "s"]
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		var planned: int = _planned.get(stat, 0)
		var value_text: String = str(stats.get_primary(stat))
		if planned > 0:
			value_text += " +%d" % planned
		_value_labels[stat].text = value_text
		_plus_buttons[stat].disabled = left <= 0
		_minus_buttons[stat].disabled = planned <= 0
	_reset_button.disabled = _planned.is_empty()

	var now: Array[PackedStringArray] = _get_derived_rows(stats)
	var after: Array[PackedStringArray] = _get_derived_rows(_preview)
	for i: int in now.size():
		var label: Label = _derived_labels[i]
		if now[i][1] == after[i][1]:
			label.text = "%s  %s" % [now[i][0], now[i][1]]
			label.remove_theme_color_override(&"font_color")
		else:
			label.text = "%s  %s > %s" % [now[i][0], now[i][1], after[i][1]]
			label.add_theme_color_override(&"font_color", changed_color)


# Name and formatted value of every derived stat, in display order.
func _get_derived_rows(stats: StatBlock) -> Array[PackedStringArray]:
	return [
		PackedStringArray(["Max HP", str(stats.max_hp)]),
		PackedStringArray(["HP regen", "%.1f/s" % stats.hp_regen]),
		PackedStringArray(["Sword dmg", "x%.2f" % stats.weapon_damage_multiplier(1.0, 0.0)]),
		PackedStringArray(["Bow dmg", "x%.2f" % stats.weapon_damage_multiplier(0.0, 1.0)]),
		PackedStringArray(["Defense", "%d%%" % roundi(stats.damage_reduction * 100.0)]),
		PackedStringArray(["Range", "x%.2f" % stats.range_multiplier]),
		PackedStringArray(["Atk speed", "x%.2f" % stats.attack_speed_multiplier]),
		PackedStringArray(["Move", "%d" % roundi(stats.move_speed)]),
		PackedStringArray(["Crit", "%d%%" % roundi(stats.crit_chance * 100.0)]),
		PackedStringArray(["Magic dmg", "x%.2f" % stats.magic_damage_multiplier]),
	]
