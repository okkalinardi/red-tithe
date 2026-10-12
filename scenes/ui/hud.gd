class_name Hud
extends CanvasLayer
## The in-game HUD: HP bar, XP bar and level, wave counter, wave timer, gold,
## and one [SkillSlot] per player skill.
##
## It never polls. Every value arrives through a signal from the system that
## owns it, and [method setup] reads the starting values once. Styling lives
## in hud_theme.tres and the bar fill colours in hud.tscn, so UI art can be
## swapped in without touching this script.

const _SKILL_SLOT_SCENE: PackedScene = preload("res://scenes/ui/skill_slot.tscn")

## Shown in place of the timer between waves.
@export var between_waves_text: String = "-"
## Shown in place of the timer during a wave without a timer.
@export var boss_wave_text: String = "BOSS"

var _player: Player
var _spawner: WaveSpawner

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _level_label: Label = %LevelLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _skill_bar: HBoxContainer = %SkillBar


func setup(player: Player, spawner: WaveSpawner) -> void:
	_player = player
	_spawner = spawner
	player.health.health_changed.connect(_on_health_changed)
	player.progression.xp_changed.connect(_on_xp_changed)
	player.progression.leveled_up.connect(_on_leveled_up)
	RunState.gold_changed.connect(_on_gold_changed)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_ended.connect(_on_wave_ended)
	spawner.time_left_changed.connect(_on_time_left_changed)

	_build_skill_slots(player)

	_on_health_changed(player.health.current_hp, player.health.max_hp)
	_on_xp_changed(player.progression.xp, player.progression.get_xp_required())
	_on_leveled_up(player.progression.level)
	_on_gold_changed(RunState.gold)
	_show_wave(spawner.current_wave_number)
	if spawner.is_wave_active():
		_on_wave_started(spawner.current_wave_number)
	else:
		_timer_label.text = between_waves_text


func _on_health_changed(current_hp: float, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_label.text = "%d/%d" % [ceili(current_hp), max_hp]


func _on_xp_changed(xp: int, xp_required: int) -> void:
	_xp_bar.max_value = xp_required
	_xp_bar.value = xp


func _on_leveled_up(level: int) -> void:
	_level_label.text = "Lv %d" % level


func _on_gold_changed(gold: int) -> void:
	_gold_label.text = str(gold)


func _on_wave_started(number: int) -> void:
	_show_wave(number)
	if _spawner.is_wave_timed():
		_on_time_left_changed(ceili(_spawner.get_time_left()))
	else:
		_timer_label.text = boss_wave_text


func _on_wave_ended(_number: int) -> void:
	_timer_label.text = between_waves_text


func _on_time_left_changed(seconds: int) -> void:
	_timer_label.text = str(seconds)


func _show_wave(number: int) -> void:
	_wave_label.text = "WAVE %d/%d" % [maxi(number, 1), _spawner.get_wave_count()]


func _build_skill_slots(player: Player) -> void:
	for child: Node in _skill_bar.get_children():
		child.queue_free()
	for slot: int in player.skills.get_slot_count():
		if player.skills.get_skill_data(slot) == null:
			continue
		var skill_slot: SkillSlot = _SKILL_SLOT_SCENE.instantiate() as SkillSlot
		_skill_bar.add_child(skill_slot)
		skill_slot.setup(player.skills, slot, player.health)
