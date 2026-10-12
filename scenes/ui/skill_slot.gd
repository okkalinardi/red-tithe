class_name SkillSlot
extends VBoxContainer
## One skill on the HUD: icon, hotkey, HP cost and cooldown.
##
## Like the rest of the HUD it is driven by signals. The only per-frame work
## is the cooldown sweep, and it runs only while that skill is cooling down.
## The cost turns red when casting would kill the player, and the slot
## flashes when a cast is refused.

const _MOUSE_BUTTON_TEXT: Dictionary[MouseButton, String] = {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
}

## Opacity of a skill that is not unlocked yet.
@export var locked_alpha: float = 0.35
@export var cost_color: Color = Color(1, 1, 1)
@export var unaffordable_color: Color = Color(1, 0.3, 0.3)
@export var refused_flash_color: Color = Color(1, 0.25, 0.25)
@export var refused_flash_time: float = 0.2
## Shown in place of a hotkey for skills that fire by themselves.
@export var automatic_text: String = "AUTO"

var _holder: SkillHolder
var _slot: int = -1
var _health: HealthComponent
var _flash_tween: Tween

@onready var _box: Control = %Box
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _cooldown_bar: ProgressBar = %CooldownBar
@onready var _cooldown_label: Label = %CooldownLabel
@onready var _key_label: Label = %KeyLabel
@onready var _cost_label: Label = %CostLabel


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	_show_cooldown()


func setup(holder: SkillHolder, slot: int, health: HealthComponent) -> void:
	_holder = holder
	_slot = slot
	_health = health
	holder.skill_level_changed.connect(_on_skill_level_changed)
	holder.cooldown_started.connect(_on_cooldown_started)
	holder.cooldown_ended.connect(_on_cooldown_ended)
	holder.cast_refused.connect(_on_cast_refused)
	health.health_changed.connect(_on_health_changed)

	var data: SkillData = holder.get_skill_data(slot)
	_icon.texture = data.icon
	_icon.visible = data.icon != null
	# Until there is icon art, the first letters of the name stand in.
	_name_label.text = data.display_name.left(2)
	_name_label.visible = data.icon == null
	_key_label.text = automatic_text if data.is_automatic() else get_key_text(data.input_action)
	_cost_label.text = "%d" % ceili(data.hp_cost) if data.hp_cost > 0.0 else "-"

	_show_unlocked()
	_on_health_changed(health.current_hp, health.max_hp)
	_show_cooldown()
	set_process(holder.get_cooldown_left(slot) > 0.0)


## The first key or mouse button bound to [param action], short enough for
## a slot: "LMB", "RMB", "Shift", "Q". Keys are named as printed on the
## player's keyboard layout. Empty if the action has no binding.
static func get_key_text(action: StringName) -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event != null:
			return _MOUSE_BUTTON_TEXT.get(mouse_event.button_index, "M%d" % mouse_event.button_index)
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		var keycode: Key = key_event.keycode
		if keycode == KEY_NONE:
			keycode = DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode)
		return OS.get_keycode_string(keycode)
	return ""


func _show_unlocked() -> void:
	_box.modulate.a = 1.0 if _holder.is_unlocked(_slot) else locked_alpha


func _show_cooldown() -> void:
	var left: float = _holder.get_cooldown_left(_slot)
	_cooldown_bar.value = _holder.get_cooldown_ratio(_slot)
	_cooldown_bar.visible = left > 0.0
	_cooldown_label.visible = left > 0.0
	_cooldown_label.text = str(ceili(left))


func _on_skill_level_changed(slot: int, _level: int) -> void:
	if slot == _slot:
		_show_unlocked()


func _on_cooldown_started(slot: int, _duration: float) -> void:
	if slot != _slot:
		return
	_show_cooldown()
	set_process(true)


func _on_cooldown_ended(slot: int) -> void:
	if slot != _slot:
		return
	set_process(false)
	_show_cooldown()


func _on_cast_refused(slot: int, _reason: SkillHolder.CastResult) -> void:
	if slot != _slot:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_box.self_modulate = refused_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_box, ^"self_modulate", Color.WHITE, refused_flash_time)


func _on_health_changed(_current_hp: float, _max_hp: int) -> void:
	var cost: float = _holder.get_skill_data(_slot).hp_cost
	var affordable: bool = cost <= 0.0 or _health.can_spend(cost)
	_cost_label.add_theme_color_override(&"font_color", cost_color if affordable else unaffordable_color)
