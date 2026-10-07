class_name HitboxComponent
extends Area2D
## An area that damages every [HurtboxComponent] it touches, again and again
## while they stay in contact. Used for enemy contact damage.
##
## Set its collision mask to the side it should hurt
## ([constant PhysicsLayers.PLAYER] for enemies) and give it a
## CollisionShape2D child.

## Emitted for every hit that lands, after the target's defense.
signal hit_landed(hurtbox: HurtboxComponent, amount: int)

## Damage of one hit, before the target's defense.
@export var damage: float = 0.0
## Seconds before the same target can be hit again.
@export var hit_interval: float = 0.5

# Seconds until each touching hurtbox can be hit again.
var _targets: Dictionary[HurtboxComponent, float] = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	for hurtbox: HurtboxComponent in _targets.keys():
		if not is_instance_valid(hurtbox):
			_targets.erase(hurtbox)
			continue
		var wait: float = _targets[hurtbox] - delta
		if wait <= 0.0:
			var dealt: int = hurtbox.take_hit(damage)
			if dealt > 0:
				wait = hit_interval
				hit_landed.emit(hurtbox, dealt)
			else:
				# The target ignored the hit (invincible); try again next frame.
				wait = 0.0
		_targets[hurtbox] = wait
	if _targets.is_empty():
		set_physics_process(false)


## Forgets every target in contact. Call when the owner is reused from a pool.
func reset() -> void:
	_targets.clear()
	set_physics_process(false)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox == null:
		return
	_targets[hurtbox] = 0.0
	set_physics_process(true)


func _on_area_exited(area: Area2D) -> void:
	_targets.erase(area as HurtboxComponent)
