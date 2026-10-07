class_name PickupData
extends Resource
## One kind of thing that lies on the ground and flies to the player:
## an XP gem, a gold coin. One .tres file per kind in res://data/pickups/.

enum Kind { XP, GOLD }

@export var id: StringName
## What collecting it gives.
@export var kind: Kind = Kind.XP
## The scene to spawn. Its root must extend [Pickup].
@export var scene: PackedScene

@export_group("Visuals")
## Shown instead of the placeholder shape when set.
@export var texture: Texture2D
## Colour of the placeholder shape.
@export var color: Color = Color.WHITE
@export var visual_scale: float = 1.0

@export_group("Flight (pixels, seconds)")
## Speed at the moment it starts flying to the collector.
@export var fly_start_speed: float = 60.0
@export var fly_acceleration: float = 700.0
## Must stay above the player's top move speed, or it never catches up.
@export var fly_max_speed: float = 320.0
## It is collected when it gets this close to the collector.
@export var collect_distance: float = 6.0
