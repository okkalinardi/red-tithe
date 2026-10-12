class_name SkillHolder
extends Node2D
## The player's skills: unlocking and upgrading, HP cost, cooldowns and
## hotkeys. One slot per entry in [member skills], in HUD order.
##
## Casting goes through one path, whether from a key or from an automatic
## skill: the skill must be unlocked, off cooldown, affordable without
## killing the player, and willing ([method Skill.can_activate]). Only then
## is HP paid through [HealthComponent] and the cooldown started.
## [codeblock]
## skills.setup(player)
## skills.learn(0)                      # a skill point unlocks Consume
## var result := skills.try_cast(0)     # what the Q key does
## [/codeblock]

## Emitted after a skill has paid its cost and fired.
signal skill_cast(slot: int)
## Emitted when a cast is attempted and refused. For HUD and sound feedback.
signal cast_refused(slot: int, reason: CastResult)
signal cooldown_started(slot: int, duration: float)
signal cooldown_ended(slot: int)
## Emitted when a skill is unlocked or upgraded.
signal skill_level_changed(slot: int, level: int)

enum CastResult {
	OK,
	## No skill in that slot.
	NO_SKILL,
	LOCKED,
	ON_COOLDOWN,
	## Paying the cost would kill the player.
	NOT_ENOUGH_HP,
	## The skill refused, for example nothing in reach.
	NO_TARGET,
	## Casting is switched off (death, menus) or the caster is dead.
	DISABLED,
	## An automatic skill was cast by key, or an active one by trigger.
	WRONG_ACTIVATION,
}

## The skills in slot order. Slot 0 is the leftmost HUD slot.
@export var skills: Array[SkillData] = []
## Testing aid: unlock every skill at level 1 when the run starts. Leave off
## in the shipped game; skill points unlock skills.
@export var unlock_all_on_start: bool = false

## Set to false to block every cast (death, menus).
var casting_enabled: bool = true

var _caster: Player
var _levels: Array[int] = []
var _cooldowns: Array[float] = []
var _instances: Array[Skill] = []


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var any_running: bool = false
	for slot: int in _cooldowns.size():
		if _cooldowns[slot] <= 0.0:
			continue
		_cooldowns[slot] -= delta
		if _cooldowns[slot] <= 0.0:
			_cooldowns[slot] = 0.0
			cooldown_ended.emit(slot)
		else:
			any_running = true
	if not any_running:
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for slot: int in skills.size():
		var data: SkillData = skills[slot]
		if data == null or data.is_automatic() or data.input_action == &"":
			continue
		if event.is_action_pressed(data.input_action):
			get_viewport().set_input_as_handled()
			try_cast(slot)
			return


## Must be called once by the owner before anything else.
func setup(caster: Player) -> void:
	_caster = caster
	var count: int = skills.size()
	_levels.resize(count)
	_levels.fill(SkillData.LOCKED_LEVEL)
	_cooldowns.resize(count)
	_cooldowns.fill(0.0)
	_instances.resize(count)
	for slot: int in count:
		var data: SkillData = skills[slot]
		if data == null:
			continue
		if not data.is_automatic() and not InputMap.has_action(data.input_action):
			push_warning("Skill '%s' uses input action '%s', which is not in the Input Map." % [data.id, data.input_action])
		if unlock_all_on_start:
			learn(slot)
	if not Events.wave_started.is_connected(_on_wave_started):
		Events.wave_started.connect(_on_wave_started)


## Number of slots, locked or not.
func get_slot_count() -> int:
	return skills.size()


func get_skill_data(slot: int) -> SkillData:
	return skills[slot] if _is_valid_slot(slot) else null


## The slot holding [param data], or -1.
func find_slot(data: SkillData) -> int:
	return skills.find(data)


## 0 when locked.
func get_level(slot: int) -> int:
	return _levels[slot] if _is_valid_slot(slot) else SkillData.LOCKED_LEVEL


func is_unlocked(slot: int) -> bool:
	return get_level(slot) >= SkillData.MIN_LEVEL


## The behaviour node of an unlocked skill, or null.
func get_skill(slot: int) -> Skill:
	return _instances[slot] if _is_valid_slot(slot) else null


## True if a skill point can unlock or upgrade [param slot].
func can_learn(slot: int) -> bool:
	var data: SkillData = get_skill_data(slot)
	return data != null and _levels[slot] < data.max_level


## Spends nothing: the caller pays the skill point
## ([method ProgressionComponent.spend_skill_point]). Unlocks the skill at
## level 1, or raises it by one level. Returns false at the maximum level.
func learn(slot: int) -> bool:
	if _caster == null:
		push_error("SkillHolder.setup() must be called before learning skills.")
		return false
	if not can_learn(slot):
		return false
	var data: SkillData = skills[slot]
	_levels[slot] += 1
	if _levels[slot] == SkillData.MIN_LEVEL:
		_instances[slot] = _create_skill(data)
	else:
		_instances[slot].set_level(_levels[slot])
	skill_level_changed.emit(slot, _levels[slot])
	return true


## Seconds until [param slot] can be cast again.
func get_cooldown_left(slot: int) -> float:
	return _cooldowns[slot] if _is_valid_slot(slot) else 0.0


## 1.0 right after a cast, 0.0 when ready. For HUD overlays.
func get_cooldown_ratio(slot: int) -> float:
	var data: SkillData = get_skill_data(slot)
	if data == null or data.cooldown <= 0.0:
		return 0.0
	return clampf(_cooldowns[slot] / data.cooldown, 0.0, 1.0)


## Ends the cooldown of [param slot] at once.
func reset_cooldown(slot: int) -> void:
	if not _is_valid_slot(slot) or _cooldowns[slot] <= 0.0:
		return
	_cooldowns[slot] = 0.0
	cooldown_ended.emit(slot)


## What would happen if [param slot] were cast now. Changes nothing.
func check_cast(slot: int) -> CastResult:
	var data: SkillData = get_skill_data(slot)
	if data == null:
		return CastResult.NO_SKILL
	if not casting_enabled or _caster == null or not _caster.health.is_alive():
		return CastResult.DISABLED
	if not is_unlocked(slot):
		return CastResult.LOCKED
	if _cooldowns[slot] > 0.0:
		return CastResult.ON_COOLDOWN
	if not _caster.health.can_spend(data.hp_cost):
		return CastResult.NOT_ENOUGH_HP
	if not _instances[slot].can_activate():
		return CastResult.NO_TARGET
	return CastResult.OK


## Casts an active skill. What a hotkey does.
func try_cast(slot: int) -> CastResult:
	var data: SkillData = get_skill_data(slot)
	if data != null and data.is_automatic():
		return _refuse(slot, CastResult.WRONG_ACTIVATION)
	return _cast(slot)


## Casts an automatic skill. Called by the skill's own script when its
## condition is met; same cost and cooldown rules as [method try_cast].
func trigger(slot: int) -> CastResult:
	var data: SkillData = get_skill_data(slot)
	if data != null and not data.is_automatic():
		return _refuse(slot, CastResult.WRONG_ACTIVATION)
	return _cast(slot)


func _cast(slot: int) -> CastResult:
	var result: CastResult = check_cast(slot)
	if result != CastResult.OK:
		return _refuse(slot, result)
	var data: SkillData = skills[slot]
	# check_cast already proved the cost is affordable; this cannot fail.
	_caster.health.spend_hp(data.hp_cost)
	_instances[slot].activate()
	if data.cooldown > 0.0:
		_cooldowns[slot] = data.cooldown
		cooldown_started.emit(slot, data.cooldown)
		set_physics_process(true)
	skill_cast.emit(slot)
	return CastResult.OK


func _refuse(slot: int, reason: CastResult) -> CastResult:
	cast_refused.emit(slot, reason)
	return reason


func _create_skill(data: SkillData) -> Skill:
	var skill: Skill
	if data.skill_scene != null:
		skill = data.skill_scene.instantiate() as Skill
		if skill == null:
			push_error("The scene of skill '%s' does not extend Skill." % data.id)
			skill = Skill.new()
	else:
		skill = Skill.new()
	skill.name = String(data.id).to_pascal_case() if data.id != &"" else "Skill"
	skill.setup(data, _caster, SkillData.MIN_LEVEL)
	add_child(skill)
	return skill


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < skills.size()


func _on_wave_started(_wave: int) -> void:
	for slot: int in skills.size():
		var data: SkillData = skills[slot]
		if data == null:
			continue
		if data.resets_on_new_wave:
			reset_cooldown(slot)
		if _instances[slot] != null:
			_instances[slot].on_wave_started()
