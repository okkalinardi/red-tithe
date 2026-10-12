class_name MeleeWeaponData
extends WeaponData
## A weapon that hits everything inside an arc in front of the wielder.
## Range ([member WeaponData.base_range]) is the radius of the arc.

@export_group("Melee")
## Full width of the arc, in degrees. 360 hits all around.
@export_range(1.0, 360.0, 1.0) var arc_degrees: float = 120.0
## Enemies this close are hit even if they are outside the arc. Stops
## enemies standing on top of the wielder from being unhittable.
@export var always_hit_radius: float = 6.0
## Most enemies one swing can hit. 0 means no limit.
@export var max_targets: int = 0

@export_group("Swing effect (placeholder)")
## Seconds the swing stays on screen.
@export var swing_time: float = 0.12
@export var swing_color: Color = Color(1.0, 1.0, 1.0, 0.45)
