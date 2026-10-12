class_name Enemy
extends CharacterBody2D
## The shared enemy. Everything specific to one kind of enemy comes from an
## [EnemyData]; this script is the behaviour of a chaser: walk straight at
## the target, keeping a little distance from other enemies.
##
## Enemies are pooled. Never instantiate or free one; use:
## [codeblock]
## var rat: Enemy = Enemy.spawn(rat_data, position, player)
## rat.despawn()          # remove without rewards
## Enemy.despawn_all()    # clear the arena
## [/codeblock]
## An enemy with a different behaviour uses [StateEnemy], which runs a state
## machine, or extends this script and overrides
## [method _get_desired_velocity]. Either way its scene is named in its data.

const _WALK_DOWN: StringName = &"walk_down"
const _WALK_UP: StringName = &"walk_up"
const _WALK_LEFT: StringName = &"walk_left"
const _WALK_RIGHT: StringName = &"walk_right"
# A tight crowd may push up to this many times harder than a single neighbour.
const _MAX_PUSH: float = 2.0

## Every enemy currently alive in the arena. Read-only for other scripts.
static var active: Array[Enemy] = []
## Each enemy recalculates its separation push once every this many physics
## frames. Higher is cheaper but makes the swarm react more slowly.
static var separation_update_interval: int = 4

static var _spawn_counter: int = 0
# Positions of all active enemies, read once per physics frame so that the
# separation loop does not ask every node for its position again and again.
static var _positions: PackedVector2Array = PackedVector2Array()
static var _positions_frame: int = -1

var data: EnemyData
## What the enemy walks towards. Usually the player.
var target: Node2D
## Applied to every damage this enemy deals. Set when it is spawned.
var damage_multiplier: float = 1.0

var _is_active: bool = false
var _separation: Vector2 = Vector2.ZERO
var _stagger: int = 0
var _animation: StringName = &""

@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $CollisionShape
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape
@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape


## Takes an enemy from the pool and places it. Returns null if the pool of
## that enemy's scene is at its limit. The multipliers make this one enemy
## tougher than its data says; waves use them to scale difficulty.
static func spawn(
	enemy_data: EnemyData,
	at: Vector2,
	target_node: Node2D,
	hp_multiplier: float = 1.0,
	damage_multiplier_value: float = 1.0,
) -> Enemy:
	var enemy: Enemy = Pools.acquire(enemy_data.scene) as Enemy
	if enemy == null:
		return null
	enemy._activate(enemy_data, at, target_node, hp_multiplier, damage_multiplier_value)
	return enemy


## Removes every enemy without rewards.
static func despawn_all() -> void:
	for enemy: Enemy in active.duplicate():
		enemy.despawn()


func _ready() -> void:
	health.died.connect(_on_died)


func _exit_tree() -> void:
	# The scene is closing; make sure the shared list does not keep us.
	active.erase(self)
	_is_active = false


func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	if (Engine.get_physics_frames() + _stagger) % separation_update_interval == 0:
		_separation = _compute_separation()
	velocity = _get_desired_velocity(delta)
	# An enemy that is standing still has nothing to collide with.
	if not velocity.is_zero_approx():
		move_and_slide()
		_update_animation()


## Removes this enemy without rewards, for example when a wave ends.
func despawn() -> void:
	if not _is_active:
		return
	_is_active = false
	active.erase(self)
	Pools.release(self)


## The velocity the enemy wants this frame. Override for other behaviours;
## call [method get_separation_velocity] to keep the swarm spacing.
func _get_desired_velocity(_delta: float) -> Vector2:
	var desired: Vector2 = get_separation_velocity()
	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > data.stop_distance:
			desired += to_target.normalized() * data.move_speed
	return desired


## The push away from nearby enemies, as a velocity.
func get_separation_velocity() -> Vector2:
	return _separation * data.move_speed * data.separation_strength


## Plays an animation if the enemy's frames have it. Does nothing when it is
## already the current one, which is the case on almost every frame.
func play_animation(animation: StringName) -> void:
	if animation == _animation:
		return
	_animation = animation
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation):
		_sprite.play(animation)


## Mirrors a side-view sprite so it looks along [param direction]. Only for
## sheets with one side view; four-direction sheets use walk_* animations.
func face_direction(direction: Vector2) -> void:
	if is_zero_approx(direction.x):
		return
	_sprite.flip_h = (direction.x > 0.0) == data.sprite_faces_left


## Tints the sprite. [constant Color.WHITE] removes the tint.
func set_tint(color: Color) -> void:
	_sprite.modulate = color


## Changes the damage of a touch, for example during a charge. Pass the
## value from the data; [member damage_multiplier] is applied here.
func set_contact_damage(amount: float) -> void:
	_hitbox.damage = amount * damage_multiplier


func _activate(
	enemy_data: EnemyData,
	at: Vector2,
	target_node: Node2D,
	hp_multiplier: float,
	damage_multiplier_value: float,
) -> void:
	data = enemy_data
	target = target_node
	damage_multiplier = damage_multiplier_value
	global_position = at
	velocity = Vector2.ZERO
	_separation = Vector2.ZERO
	_spawn_counter += 1
	_stagger = _spawn_counter

	health.configure(maxi(roundi(data.max_hp * hp_multiplier), 1))
	(_body_shape.shape as CircleShape2D).radius = data.body_radius
	(_hurtbox_shape.shape as CircleShape2D).radius = data.hurtbox_radius
	(_hitbox_shape.shape as CircleShape2D).radius = data.contact_radius
	set_contact_damage(data.contact_damage)
	_hitbox.hit_interval = data.contact_interval
	_hitbox.reset()

	_sprite.sprite_frames = data.sprite_frames
	_sprite.scale = Vector2.ONE * data.visual_scale
	_sprite.offset = data.sprite_offset
	_sprite.flip_h = false
	_sprite.modulate = Color.WHITE
	_animation = &""
	play_animation(_WALK_DOWN)

	active.append(self)
	_is_active = true


func _compute_separation() -> Vector2:
	if data.separation_strength <= 0.0:
		return Vector2.ZERO
	_refresh_positions()
	var mine: Vector2 = global_position
	var radius: float = data.separation_radius
	var radius_squared: float = radius * radius
	var push: Vector2 = Vector2.ZERO
	var on_this_spot: int = 0
	for other: Vector2 in _positions:
		var away: Vector2 = mine - other
		var distance_squared: float = away.length_squared()
		if distance_squared >= radius_squared:
			continue
		if distance_squared < 0.0001:
			# This enemy itself, or another one on exactly the same spot.
			on_this_spot += 1
			continue
		var distance: float = sqrt(distance_squared)
		# Full strength when touching, fading to nothing at the radius.
		push += away / distance * (1.0 - distance / radius)
	if on_this_spot > 1:
		# Exactly stacked: leave in a direction that differs per enemy.
		push += Vector2.from_angle(_stagger * 2.399963)
	return push.limit_length(_MAX_PUSH)


static func _refresh_positions() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _positions_frame:
		return
	_positions_frame = frame
	_positions.resize(active.size())
	for i: int in active.size():
		_positions[i] = active[i].global_position


func _update_animation() -> void:
	if velocity.length_squared() < 1.0:
		return
	if absf(velocity.x) > absf(velocity.y):
		play_animation(_WALK_RIGHT if velocity.x > 0.0 else _WALK_LEFT)
	else:
		play_animation(_WALK_DOWN if velocity.y > 0.0 else _WALK_UP)


func _on_died() -> void:
	if not _is_active:
		return
	Events.enemy_died.emit(data, global_position)
	despawn()
