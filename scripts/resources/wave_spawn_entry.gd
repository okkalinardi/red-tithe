class_name WaveSpawnEntry
extends Resource
## One kind of enemy in a wave, and how often it is picked.

@export var enemy: EnemyData
## Share of the spawns, relative to the other entries of the wave. An entry
## with weight 3 is picked three times as often as one with weight 1.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
