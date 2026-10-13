class_name LevelUpScreen
extends CanvasLayer
## Spend unspent stat points and skill points between waves.
##
## [method open] pauses the game and shows the six primary stats and the
## player's skills. Plus and minus buttons build up a plan; the right-hand
## list previews every derived stat with the plan applied. One skill point
## unlocks a skill or raises it one level, in any order. Nothing is spent
## until Done, so Reset can undo a misclick. Points left unspent are kept for
## next time.

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
## Colour of a skill name while it is still locked.
@export var locked_color: Color = Color(0.6, 0.6, 0.6)

var _player: Player
var _planned: Dictionary[StatBlock.Stat, int] = {}
var _preview: StatBlock
var _value_labels: Dictionary[StatBlock.Stat, Label] = {}
var _plus_buttons: Dictionary[StatBlock.Stat, Button] = {}
var _minus_buttons: Dictionary[StatBlock.Stat, Button] = {}
var _derived_labels: Array[Label] = []
# Skill points planned per skill slot.
var _planned_skills: Dictionary[int, int] = {}
var _skill_name_labels: Array[Label] = []
var _skill_level_labels: Array[Label] = []
var _skill_plus_buttons: Array[Button] = []
var _skill_minus_buttons: Array[Button] = []

@onready var _points_label: Label = %PointsLabel
@onready var _stat_grid: GridContainer = %StatGrid
@onready var _derived_list: VBoxContainer = %DerivedList
@onready var _skill_points_label: Label = %SkillPointsLabel
@onready var _skill_row: VBoxContainer = %SkillRow
@onready var _reset_button: Button = %ResetButton
@onready var _done_button: Button = %DoneButton


func _ready() -> void:
	# Runs while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_stat_rows()
	_reset_button.pressed.connect(reset_plan)
	_done_button.pressed.connect(confirm)


## True if [param player] has a stat point to spend, or a skill point and a
## skill it could go into. The run opens the screen between waves only then.
static func has_points_to_spend(player: Player) -> bool:
	if player.progression.stat_points > 0:
		return true
	if player.progression.skill_points <= 0:
		return false
	for slot: int in player.skills.get_slot_count():
		if player.skills.can_learn(slot):
			return true
	return false


## Shows the screen for [param player] and pauses the game.
func open(player: Player) -> void:
	if player != _player:
		_player = player
		_build_skill_entries()
	_planned.clear()
	_planned_skills.clear()
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
	_planned_skills.clear()
	_refresh()


## Adds one skill point to the plan for the skill in [param slot]. Returns
## false if no skill point is left or the skill would pass its maximum level.
func plan_skill_point(slot: int) -> bool:
	if get_skill_points_left() <= 0 or get_planned_skill_level(slot) >= _get_max_level(slot):
		return false
	_planned_skills[slot] = _planned_skills.get(slot, 0) + 1
	_refresh()
	return true


## Takes one skill point back out of the plan for [param slot].
func unplan_skill_point(slot: int) -> bool:
	if _planned_skills.get(slot, 0) <= 0:
		return false
	_planned_skills[slot] -= 1
	if _planned_skills[slot] == 0:
		_planned_skills.erase(slot)
	_refresh()
	return true


## Skill points not yet in the plan.
func get_skill_points_left() -> int:
	var planned_total: int = 0
	for slot: int in _planned_skills:
		planned_total += _planned_skills[slot]
	return _player.progression.skill_points - planned_total


## The level the skill in [param slot] would have with the plan applied.
func get_planned_skill_level(slot: int) -> int:
	return _player.skills.get_level(slot) + _planned_skills.get(slot, 0)


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
	for slot: int in _planned_skills:
		for i: int in _planned_skills[slot]:
			# The point is paid only for a skill that can still take it.
			if _player.skills.can_learn(slot) and _player.progression.spend_skill_point():
				_player.skills.learn(slot)
	_planned.clear()
	_planned_skills.clear()
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


# One row per skill slot: [name over level], minus, plus. Rebuilt when the
# screen is opened for a different player.
func _build_skill_entries() -> void:
	for child: Node in _skill_row.get_children():
		_skill_row.remove_child(child)
		child.queue_free()
	_skill_name_labels.clear()
	_skill_level_labels.clear()
	_skill_plus_buttons.clear()
	_skill_minus_buttons.clear()
	for slot: int in _player.skills.get_slot_count():
		var data: SkillData = _player.skills.get_skill_data(slot)
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override(&"separation", 2)
		entry.tooltip_text = _get_skill_hint(data)
		entry.mouse_filter = Control.MOUSE_FILTER_PASS
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(62, 0)
		info.add_theme_constant_override(&"separation", -4)
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		var name_label := Label.new()
		name_label.text = data.display_name if data != null else "-"
		name_label.add_theme_font_size_override(&"font_size", 8)
		var level_label := Label.new()
		level_label.add_theme_font_size_override(&"font_size", 8)
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(16, 14)
		minus.pressed.connect(unplan_skill_point.bind(slot))
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(16, 14)
		plus.tooltip_text = entry.tooltip_text
		plus.pressed.connect(plan_skill_point.bind(slot))
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(name_label)
		info.add_child(level_label)
		entry.add_child(info)
		entry.add_child(minus)
		entry.add_child(plus)
		_skill_row.add_child(entry)
		_skill_name_labels.append(name_label)
		_skill_level_labels.append(level_label)
		_skill_minus_buttons.append(minus)
		_skill_plus_buttons.append(plus)


func _get_skill_hint(data: SkillData) -> String:
	if data == null:
		return ""
	var cost: String = "free" if data.hp_cost <= 0.0 else "%d HP" % ceili(data.hp_cost)
	return "%s\n%s\nCost %s, cooldown %s s. +%d%% per level." % [
		data.display_name, data.description, cost, String.num(data.cooldown),
		roundi(data.value_growth_per_level * 100.0),
	]


func _get_max_level(slot: int) -> int:
	var data: SkillData = _player.skills.get_skill_data(slot)
	return data.max_level if data != null else 0


func _refresh_skills() -> void:
	var left: int = get_skill_points_left()
	_skill_points_label.text = "SKILLS  %d point%s" % [left, "" if left == 1 else "s"]
	for slot: int in _skill_level_labels.size():
		var level: int = _player.skills.get_level(slot)
		var planned_level: int = get_planned_skill_level(slot)
		var max_level: int = _get_max_level(slot)
		var level_label: Label = _skill_level_labels[slot]
		if planned_level == SkillData.LOCKED_LEVEL:
			level_label.text = "Locked"
		elif planned_level == level:
			level_label.text = "Lv %d/%d" % [level, max_level]
		elif level == SkillData.LOCKED_LEVEL:
			level_label.text = "Unlock > Lv %d" % planned_level
		else:
			level_label.text = "Lv %d > %d" % [level, planned_level]
		if planned_level != level:
			level_label.add_theme_color_override(&"font_color", changed_color)
		else:
			level_label.remove_theme_color_override(&"font_color")
		if planned_level == SkillData.LOCKED_LEVEL:
			_skill_name_labels[slot].add_theme_color_override(&"font_color", locked_color)
		else:
			_skill_name_labels[slot].remove_theme_color_override(&"font_color")
		_skill_plus_buttons[slot].disabled = left <= 0 or planned_level >= max_level
		_skill_minus_buttons[slot].disabled = planned_level <= level


func _refresh() -> void:
	if _player == null:
		return
	_refresh_skills()
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
	_reset_button.disabled = _planned.is_empty() and _planned_skills.is_empty()

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
