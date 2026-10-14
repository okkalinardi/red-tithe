class_name Player
extends CharacterBody2D
## The player character: 8-direction movement, mouse aim, and the follow camera.
##
## Move speed comes from [member stats]. Weapons and skills read
## [member aim_direction] and can be parented to the AimPivot node, which
## always points at the mouse. The sprite faces the aim, not the movement.

## Order matches the columns of the sprite sheets.
enum Facing { DOWN, UP, LEFT, RIGHT }

const _IDLE_ANIMATIONS: Array[StringName] = [&"idle_down", &"idle_up", &"idle_left", &"idle_right"]
const _WALK_ANIMATIONS: Array[StringName] = [&"walk_down", &"walk_up", &"walk_left", &"walk_right"]

## Starting stats. Leave empty to start with 0 in every stat.
@export var base_stats: StatBlock

## This player's own stats. Never shared with another character.
var stats: StatBlock
## Unit vector from the player towards the mouse.
var aim_direction: Vector2 = Vector2.RIGHT
## The one of four directions the sprite is drawn in.
var facing: Facing = Facing.DOWN
## Unit vector of the movement keys held, or zero when none are.
var move_direction: Vector2 = Vector2.ZERO
## False while a menu such as the shop is open: no moving, aiming, firing
## or casting. Health keeps regenerating.
var controls_enabled: bool = true

var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_time_left: float = 0.0

@onready var health: HealthComponent = $Health
@onready var weapons: WeaponHolder = $Weapons
@onready var skills: SkillHolder = $Skills
@onready var progression: ProgressionComponent = $Progression
@onready var collector: PickupCollector = $PickupCollector
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _aim_pivot: Node2D = $AimPivot
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	if base_stats != null:
		stats = base_stats.duplicate() as StatBlock
	else:
		stats = StatBlock.new()
	health.bind_stats(stats)
	health.died.connect(_on_died)
	weapons.setup(stats)
	progression.setup(stats)
	skills.setup(self)
	collector.collected.connect(_on_pickup_collected)
	_update_animation()


func _physics_process(delta: float) -> void:
	# get_vector normalises diagonals, so moving diagonally is not faster.
	var input: Vector2 = Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	move_direction = input.normalized() if not input.is_zero_approx() else Vector2.ZERO
	if _dash_time_left > 0.0:
		# A dash overrides the keys. Walls still stop it.
		var step: float = minf(delta, _dash_time_left)
		_dash_time_left -= delta
		velocity = _dash_velocity * (step / delta)
	else:
		velocity = input * stats.move_speed
	move_and_slide()


func _process(_delta: float) -> void:
	if controls_enabled:
		aim_at(get_global_mouse_position())
	_update_animation()


## Switches moving, aiming, firing and casting on or off, for menus that do
## not pause the game. Has no effect on a dead player.
func set_controls_enabled(enabled: bool) -> void:
	if not health.is_alive():
		return
	controls_enabled = enabled
	weapons.firing_enabled = enabled
	skills.casting_enabled = enabled


## Moves [param distance] pixels along [param direction] over [param duration]
## seconds, ignoring the movement keys. Walls stop it like normal movement.
## There is no invincibility.
func dash(direction: Vector2, distance: float, duration: float) -> void:
	if direction.is_zero_approx() or distance <= 0.0:
		return
	var time: float = maxf(duration, 0.001)
	_dash_velocity = direction.normalized() * distance / time
	_dash_time_left = time


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## Tints the sprite, for example while Berserk lasts. [constant Color.WHITE]
## removes the tint.
func set_tint(color: Color) -> void:
	_sprite.modulate = color


## Points the player at a position in world space.
func aim_at(target: Vector2) -> void:
	var to_target: Vector2 = target - global_position
	# Keep the previous aim when the mouse is exactly on the player.
	if to_target.is_zero_approx():
		return
	aim_direction = to_target.normalized()
	weapons.aim_direction = aim_direction
	_aim_pivot.rotation = aim_direction.angle()
	if absf(aim_direction.x) > absf(aim_direction.y):
		facing = Facing.RIGHT if aim_direction.x > 0.0 else Facing.LEFT
	else:
		facing = Facing.DOWN if aim_direction.y > 0.0 else Facing.UP
	_update_animation()


## Stops the camera from showing anything outside [param bounds] (world space).
func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y
	_camera.reset_smoothing()


func _update_animation() -> void:
	var is_moving: bool = not velocity.is_zero_approx()
	var animations: Array[StringName] = _WALK_ANIMATIONS if is_moving else _IDLE_ANIMATIONS
	var wanted: StringName = animations[facing]
	if _sprite.animation != wanted or not _sprite.is_playing():
		_sprite.play(wanted)


func _on_died() -> void:
	velocity = Vector2.ZERO
	_dash_time_left = 0.0
	set_physics_process(false)
	set_process(false)
	weapons.firing_enabled = false
	skills.casting_enabled = false
	collector.disable()
	_sprite.play(&"dead")
	Events.player_died.emit()


func _on_pickup_collected(data: PickupData, amount: int) -> void:
	match data.kind:
		PickupData.Kind.XP:
			progression.add_xp(amount)
		PickupData.Kind.GOLD:
			RunState.add_gold(amount)
