class_name HealthComponent
extends Node
## HP for anything that can be hurt: the player and every enemy.
##
## Add it as a child node. A character with a [StatBlock] calls
## [method bind_stats], and Max HP, regen and defense then follow the stats.
## Without stats (most enemies) it uses the exported base values and has no
## defense.
## [codeblock]
## health.bind_stats(stats)
## health.died.connect(_on_died)
## var dealt: int = health.take_damage(12.0)   # an enemy hit
## if health.spend_hp(20.0):                   # a skill cost
##     cast()
## [/codeblock]

## Emitted when the HP shown to the player changes (whole numbers) or Max HP changes.
signal health_changed(current_hp: float, max_hp: int)
## Emitted for every hit that lands, after defense. Not emitted by [method spend_hp].
signal damaged(amount: int)
## Emitted once, when HP reaches 0.
signal died

const _FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")
## A skill cost may never take HP below this.
const _MIN_HP_AFTER_SPEND: float = 1.0

@export_group("Without a StatBlock")
@export var base_max_hp: int = 100
## HP per second.
@export var base_hp_regen: float = 0.0

@export_group("Hits")
## Seconds of invincibility after a hit lands. 0 for enemies.
@export var invincibility_time: float = 0.0
## The sprite that flashes white when hit. Optional.
@export var flash_target: CanvasItem
@export var flash_time: float = 0.1

var max_hp: int
## Fractional, because regen adds a little every frame. Round up for display.
var current_hp: float
## Optional last-chance hook, for example Berserk. Called with no arguments
## when a hit would kill; if it returns true the owner survives at 1 HP.
var lethal_hit_handler: Callable

# One material shared by every flashing sprite, so flashes do not break batching.
static var _flash_material: ShaderMaterial

var _stats: StatBlock
var _is_dead: bool = false
var _invincibility_left: float = 0.0
var _flash_left: float = 0.0
var _is_flashing: bool = false
var _material_before_flash: Material
var _last_reported_hp: int = -1


func _ready() -> void:
	if _stats == null:
		max_hp = base_max_hp
		current_hp = max_hp
		_report_health(true)
	_update_processing()


func _exit_tree() -> void:
	_end_flash()


func _physics_process(delta: float) -> void:
	if _is_flashing:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_end_flash()
	if _is_dead:
		_update_processing()
		return
	if _invincibility_left > 0.0:
		_invincibility_left -= delta
	var regen: float = _get_regen()
	if regen > 0.0 and current_hp < max_hp:
		_set_hp(current_hp + regen * delta)
	_update_processing()


## Makes Max HP, regen and defense follow [param stats], and fills HP.
func bind_stats(stats: StatBlock) -> void:
	if _stats != null:
		_stats.changed.disconnect(_on_stats_changed)
	_stats = stats
	_stats.changed.connect(_on_stats_changed)
	max_hp = _stats.max_hp
	current_hp = max_hp
	_report_health(true)
	_update_processing()


## Applies an enemy hit of [param raw_damage] and returns the damage dealt
## after defense. Returns 0 if the hit was ignored (dead or invincible).
func take_damage(raw_damage: float) -> int:
	if _is_dead or raw_damage <= 0.0 or is_invincible():
		return 0
	var dealt: int
	if _stats != null:
		dealt = _stats.apply_defense(raw_damage)
	else:
		dealt = maxi(roundi(raw_damage), 1)
	var remaining: float = current_hp - dealt
	if remaining <= 0.0 and lethal_hit_handler.is_valid() and lethal_hit_handler.call():
		remaining = 1.0
	_invincibility_left = invincibility_time
	_start_flash()
	_set_hp(remaining)
	damaged.emit(dealt)
	_update_processing()
	if current_hp <= 0.0:
		_is_dead = true
		died.emit()
	return dealt


## True if [method spend_hp] would succeed for [param cost].
func can_spend(cost: float) -> bool:
	return not _is_dead and (cost <= 0.0 or current_hp - cost >= _MIN_HP_AFTER_SPEND)


## Pays a skill cost. Ignores defense and invincibility, and never kills:
## it returns false and spends nothing if the cost would leave less than 1 HP.
func spend_hp(cost: float) -> bool:
	if not can_spend(cost):
		return false
	if cost > 0.0:
		_set_hp(current_hp - cost)
		_update_processing()
	return true


## Restores HP and returns the amount actually restored.
func heal(amount: float) -> float:
	if _is_dead or amount <= 0.0:
		return 0.0
	var before: float = current_hp
	_set_hp(current_hp + amount)
	return current_hp - before


## Sets Max HP and regen for a character without a StatBlock, and fills HP.
## Pooled enemies call this every time they are spawned.
func configure(new_max_hp: int, hp_regen: float = 0.0) -> void:
	base_max_hp = new_max_hp
	base_hp_regen = hp_regen
	if _stats == null:
		max_hp = base_max_hp
	restore_full()
	_report_health(true)


## Back to full HP and alive. For the start of a run.
func restore_full() -> void:
	_is_dead = false
	_invincibility_left = 0.0
	_end_flash()
	_set_hp(max_hp)
	_update_processing()


func is_alive() -> bool:
	return not _is_dead


func is_invincible() -> bool:
	return _invincibility_left > 0.0


## 0.0 to 1.0, for HP bars.
func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0


func _get_regen() -> float:
	return _stats.hp_regen if _stats != null else base_hp_regen


# A health node with nothing to count down or regenerate does no per-frame
# work. This matters with 100 enemies alive.
func _update_processing() -> void:
	var is_regenerating: bool = not _is_dead and current_hp < max_hp and _get_regen() > 0.0
	set_physics_process(_is_flashing or _invincibility_left > 0.0 or is_regenerating)


func _set_hp(value: float) -> void:
	current_hp = clampf(value, 0.0, max_hp)
	_report_health(false)


# Regen changes HP by a fraction every frame; listeners only hear about it
# when the whole number on screen would change.
func _report_health(force: bool) -> void:
	var shown: int = ceili(current_hp)
	if force or shown != _last_reported_hp:
		_last_reported_hp = shown
		health_changed.emit(current_hp, max_hp)


func _on_stats_changed() -> void:
	if _stats.max_hp == max_hp:
		return
	# Raising Max HP does not heal; lowering it clamps current HP.
	max_hp = _stats.max_hp
	current_hp = minf(current_hp, max_hp)
	_report_health(true)
	_update_processing()


func _start_flash() -> void:
	if flash_target == null or flash_time <= 0.0:
		return
	if not _is_flashing:
		if _flash_material == null:
			_flash_material = ShaderMaterial.new()
			_flash_material.shader = _FLASH_SHADER
		_material_before_flash = flash_target.material
		flash_target.material = _flash_material
		_is_flashing = true
	_flash_left = flash_time


func _end_flash() -> void:
	if not _is_flashing:
		return
	_is_flashing = false
	_flash_left = 0.0
	if is_instance_valid(flash_target):
		flash_target.material = _material_before_flash
	_material_before_flash = null
