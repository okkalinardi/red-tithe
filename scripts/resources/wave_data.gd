class_name WaveData
extends Resource
## One wave: which enemies come, how fast, and how much tougher they are.
## One .tres file per wave in res://data/waves/.

@export_group("Length")
## Seconds. 0 means no timer: the wave ends when its boss dies.
@export var duration: float = 30.0

@export_group("Enemies")
@export var entries: Array[WaveSpawnEntry] = []
## Optional. Spawned once when the wave starts, in addition to the entries.
@export var boss: EnemyData

@export_group("Spawn rate")
## Seconds between batches.
@export_range(0.05, 30.0, 0.05) var spawn_interval: float = 1.5
## Enemies per batch.
@export_range(1, 50) var batch_size: int = 2
## No batch is spawned while this many enemies are alive. The spawner's own
## cap also applies, so this can only lower the limit.
@export_range(1, 100) var max_alive: int = 100

@export_group("Scaling")
## Multiplies the Max HP of every enemy spawned by this wave.
@export var hp_multiplier: float = 1.0
## Multiplies the damage of every enemy spawned by this wave.
@export var damage_multiplier: float = 1.0


## True if the wave ends on a timer rather than on its boss dying.
func is_timed() -> bool:
	return duration > 0.0


## A random enemy from the entries, by weight. Null if there are none.
func pick_enemy(rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for entry: WaveSpawnEntry in entries:
		if entry != null and entry.enemy != null:
			total += entry.weight
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	var last: EnemyData = null
	for entry: WaveSpawnEntry in entries:
		if entry == null or entry.enemy == null or entry.weight <= 0.0:
			continue
		last = entry.enemy
		roll -= entry.weight
		if roll < 0.0:
			return last
	return last
