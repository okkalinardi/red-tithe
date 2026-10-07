class_name Pickup
extends Area2D
## A pooled drop on the ground. It does nothing until a [PickupCollector]
## touches it; then it flies to the collector and is collected.
##
## Never instantiate or free one; use:
## [codeblock]
## Pickup.spawn(xp_gem_data, position, 3)
## Pickup.despawn_all()
## [/codeblock]
## Leave Monitorable on in the scene, or collectors cannot detect it.

## Every pickup currently lying in the arena or flying. Read-only for others.
static var active: Array[Pickup] = []

var data: PickupData
## How much XP or gold this one pickup is worth.
var amount: int = 0

var _collector: PickupCollector
var _speed: float = 0.0
var _is_active: bool = false

@onready var _shape_visual: Polygon2D = $Visual
@onready var _sprite: Sprite2D = $Sprite


## Takes a pickup from the pool and places it. Returns null if the pool of
## its scene is at its limit.
static func spawn(pickup_data: PickupData, at: Vector2, pickup_amount: int) -> Pickup:
	var pickup: Pickup = Pools.acquire(pickup_data.scene) as Pickup
	if pickup == null:
		return null
	pickup._activate(pickup_data, at, pickup_amount)
	return pickup


## Removes every pickup without giving its value to anyone.
static func despawn_all() -> void:
	for pickup: Pickup in active.duplicate():
		pickup.despawn()


func _exit_tree() -> void:
	active.erase(self)
	_is_active = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_collector):
		stop_flying()
		return
	_speed = minf(_speed + data.fly_acceleration * delta, data.fly_max_speed)
	var to_collector: Vector2 = _collector.global_position - global_position
	var step: float = _speed * delta
	if to_collector.length() <= maxf(data.collect_distance, step):
		_collector.collect(self)
		return
	global_position += to_collector.normalized() * step


## Starts flying to [param collector]. Does nothing if it is already flying.
func fly_to(collector: PickupCollector) -> void:
	if not _is_active or is_flying():
		return
	_collector = collector
	_speed = data.fly_start_speed
	set_physics_process(true)


func is_flying() -> bool:
	return _collector != null


func is_flying_to(collector: PickupCollector) -> bool:
	return _collector == collector


## Drops back to the ground where it is.
func stop_flying() -> void:
	_collector = null
	set_physics_process(false)


## Removes this pickup without giving its value to anyone.
func despawn() -> void:
	if not _is_active:
		return
	_is_active = false
	active.erase(self)
	stop_flying()
	Pools.release(self)


func _activate(pickup_data: PickupData, at: Vector2, pickup_amount: int) -> void:
	data = pickup_data
	amount = pickup_amount
	global_position = at
	stop_flying()
	_sprite.texture = data.texture
	_sprite.visible = data.texture != null
	_shape_visual.visible = data.texture == null
	_shape_visual.color = data.color
	_shape_visual.scale = Vector2.ONE * data.visual_scale
	_sprite.scale = Vector2.ONE * data.visual_scale
	active.append(self)
	_is_active = true
