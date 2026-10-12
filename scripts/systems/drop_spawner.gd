class_name DropSpawner
extends Node
## Turns enemy deaths into pickups: an XP gem and a gold coin per kill, worth
## the enemy's XP and gold rewards.
##
## It listens to [signal Events.enemy_died] by itself. Call [method setup]
## once so that, when a wave ends, the leftovers can fly to the collector.

## The pickup dropped for an enemy's XP reward. Leave empty to drop none.
@export var xp_pickup: PickupData
## The pickup dropped for an enemy's gold reward. Leave empty to drop none.
@export var gold_pickup: PickupData
## Drops land within this distance of where the enemy died, in pixels.
@export var scatter_radius: float = 8.0
## When a wave ends, everything left on the ground flies to the collector.
@export var collect_all_on_wave_end: bool = true
## Most pickups on the ground at once. Past this, a new drop adds its value
## to the newest pickup of its kind instead of appearing, so nothing is lost.
@export var max_on_ground: int = 300
## Pickups created up front, so none is instantiated mid-combat.
@export var pool_prewarm: int = 128

## Replace with a seeded generator to make scatter repeatable in tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _collector: PickupCollector
var _newest: Dictionary[PickupData, Pickup] = {}


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.wave_completed.connect(_on_wave_completed)


func setup(collector: PickupCollector) -> void:
	_collector = collector
	var scenes: Array[PackedScene] = []
	for pickup_data: PickupData in [xp_pickup, gold_pickup]:
		if pickup_data != null and pickup_data.scene != null and not scenes.has(pickup_data.scene):
			scenes.append(pickup_data.scene)
	for scene: PackedScene in scenes:
		Pools.prewarm(scene, pool_prewarm)


## Drops [param amount] of one kind of pickup near [param at].
func drop(pickup_data: PickupData, at: Vector2, amount: int) -> void:
	if pickup_data == null or amount <= 0:
		return
	var newest: Pickup = _newest.get(pickup_data)
	if Pickup.active.size() >= max_on_ground and is_instance_valid(newest) and Pickup.active.has(newest):
		newest.amount += amount
		return
	var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * scatter_radius
	var pickup: Pickup = Pickup.spawn(pickup_data, at + offset, amount)
	if pickup != null:
		_newest[pickup_data] = pickup


func _on_enemy_died(data: EnemyData, at: Vector2) -> void:
	drop(xp_pickup, at, data.xp_reward)
	drop(gold_pickup, at, data.gold_reward)


func _on_wave_completed(_wave: int) -> void:
	if collect_all_on_wave_end and is_instance_valid(_collector):
		_collector.attract_all()
