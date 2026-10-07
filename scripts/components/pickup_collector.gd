class_name PickupCollector
extends Area2D
## Pulls in every [Pickup] that comes within [member pickup_range] and
## reports what was collected. It does not decide what a pickup is worth to
## its owner; the owner listens to [signal collected].

signal collected(data: PickupData, amount: int)

## Pickups closer than this fly to the collector, in pixels.
@export var pickup_range: float = 40.0:
	set(value):
		pickup_range = maxf(value, 0.0)
		if _circle != null:
			_circle.radius = pickup_range

var _circle: CircleShape2D


func _ready() -> void:
	# Detects pickups and nothing else; nothing needs to detect it.
	collision_layer = 0
	collision_mask = PhysicsLayers.PICKUP
	_circle = CircleShape2D.new()
	_circle.radius = pickup_range
	var shape := CollisionShape2D.new()
	shape.shape = _circle
	add_child(shape)
	area_entered.connect(_on_area_entered)


## Called by a pickup when it arrives.
func collect(pickup: Pickup) -> void:
	var data: PickupData = pickup.data
	var amount: int = pickup.amount
	pickup.despawn()
	collected.emit(data, amount)


## Makes every pickup in the arena fly here, whatever its distance.
func attract_all() -> void:
	for pickup: Pickup in Pickup.active.duplicate():
		pickup.fly_to(self)


## Stops pulling pickups in, and drops the ones already on their way.
func disable() -> void:
	set_deferred(&"monitoring", false)
	for pickup: Pickup in Pickup.active:
		if pickup.is_flying_to(self):
			pickup.stop_flying()


func _on_area_entered(area: Area2D) -> void:
	var pickup: Pickup = area as Pickup
	if pickup != null:
		pickup.fly_to(self)
