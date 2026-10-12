class_name ShooterEnemyData
extends EnemyData
## An enemy that keeps its distance, circles the target and fires aimed
## projectiles from a shared pool. Used by the Carrion Crow.
##
## [member EnemyData.move_speed] is its flying speed and
## [member EnemyData.contact_damage] is the damage of a touch; the danger is
## the projectiles.

@export_group("Distance")
## Backs away when the target is closer than this, in pixels.
@export var min_distance: float = 70.0
## Flies closer when the target is farther than this, in pixels.
@export var max_distance: float = 120.0
## Share of [member EnemyData.move_speed] spent circling the target while it
## is between the two distances. 0 hovers in place.
@export_range(0.0, 1.0, 0.05) var orbit_speed_ratio: float = 0.5

@export_group("Shooting")
## Only fires when the target is this close, in pixels, and the shooter is
## on screen, so no shot comes from out of sight.
@export var fire_range: float = 160.0
## Seconds between attacks. Each wait varies by up to
## [member fire_interval_variance] either way, so a flock does not fire in step.
@export var fire_interval: float = 2.4
@export_range(0.0, 0.9, 0.05) var fire_interval_variance: float = 0.15
## Seconds before the first attack after spawning: a random value in this range.
@export var first_shot_delay: Vector2 = Vector2(1.0, 2.0)
## Seconds of wind-up before a shot. This is the player's warning.
@export var aim_time: float = 0.45
## Colour the sprite is tinted during the wind-up.
@export var aim_tint: Color = Color(1.0, 0.55, 0.55)
## Seconds the shooter stays still after firing.
@export var recover_time: float = 0.35

@export_group("Projectile")
## Its root must extend [Projectile]. Every shooter using the same scene
## shares one pool.
@export var projectile_scene: PackedScene
## Damage of one hit, before the target's defense and the wave multiplier.
@export var projectile_damage: float = 8.0
## Pixels per second.
@export var projectile_speed: float = 100.0
## Pixels a projectile travels before it disappears.
@export var projectile_range: float = 240.0
@export_range(1, 16) var projectiles_per_shot: int = 1
## Total width of the fan, in degrees, when firing more than one projectile.
@export_range(0.0, 360.0, 1.0) var spread_degrees: float = 0.0
## Where shots leave from, relative to the shooter's position (its shadow).
@export var muzzle_offset: Vector2 = Vector2(0, -4)
## Projectiles created up front. Shared by every shooter using the scene.
@export var projectile_pool_prewarm: int = 32
