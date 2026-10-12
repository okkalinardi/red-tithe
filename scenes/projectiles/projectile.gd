class_name Projectile
extends Area2D
## A pooled projectile that flies in a straight line.
##
## It knows nothing about damage: whoever launches it passes a callback that
## is called for each [HurtboxComponent] it touches. Its collision layer and
## mask, shape and looks are set in its scene. It returns itself to its pool
## when it runs out of range or pierce, or hits the world.
##
## Leave Monitorable on in the scene. Godot treats a non-monitorable area as
## static, and a static area never detects walls.

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _distance_left: float = 0.0
var _pierce_left: int = 0
var _on_hit: Callable
var _already_hit: Array[HurtboxComponent] = []
var _is_finished: bool = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## Starts a flight. [param on_hit] is called with the [HurtboxComponent] hit.
func launch(
	from: Vector2,
	direction: Vector2,
	speed: float,
	max_distance: float,
	pierce: int,
	on_hit: Callable,
) -> void:
	global_position = from
	rotation = direction.angle()
	_direction = direction
	_speed = speed
	_distance_left = max_distance
	_pierce_left = pierce
	_on_hit = on_hit
	_already_hit.clear()
	_is_finished = false


func _physics_process(delta: float) -> void:
	if _is_finished:
		return
	var step: float = _speed * delta
	global_position += _direction * step
	_distance_left -= step
	if _distance_left <= 0.0:
		_finish()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if _is_finished or hurtbox == null or _already_hit.has(hurtbox):
		return
	_already_hit.append(hurtbox)
	# The launcher may be gone (weapon sold); the projectile still stops.
	if _on_hit.is_valid():
		_on_hit.call(hurtbox)
	if _pierce_left <= 0:
		_finish()
	else:
		_pierce_left -= 1


func _on_body_entered(body: Node2D) -> void:
	# Only the world stops a projectile. Characters are hit through hurtboxes.
	var collider: CollisionObject2D = body as CollisionObject2D
	if collider == null or collider.collision_layer & PhysicsLayers.WORLD != 0:
		_finish()


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	Pools.release(self)
