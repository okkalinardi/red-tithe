class_name ChargerEnemyData
extends EnemyData
## An enemy that walks to mid range, winds up, charges in a straight line and
## then rests. Used by the Stray; reusable for the boss.
##
## [member EnemyData.move_speed] is the walking speed of the approach and
## [member EnemyData.contact_damage] is the damage of a touch outside a charge.

@export_group("Charge")
## Starts winding up when the target is this close, in pixels.
@export var charge_range: float = 90.0
## Seconds of wind-up. This is the player's warning.
@export var telegraph_time: float = 0.6
## Colour the sprite is tinted during the wind-up.
@export var telegraph_tint: Color = Color(1.0, 0.45, 0.45)
## Pixels per second.
@export var charge_speed: float = 220.0
## Pixels. The charge also ends early if it hits a wall.
@export var charge_distance: float = 140.0
## Damage of a touch during the charge, before the target's defense.
@export var charge_damage: float = 15.0
## Seconds of standing still after a charge. This is the player's opening.
@export var recover_time: float = 0.9
