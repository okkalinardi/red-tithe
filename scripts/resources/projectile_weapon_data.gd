class_name ProjectileWeaponData
extends WeaponData
## A weapon that fires pooled projectiles along the aim.
## Range ([member WeaponData.base_range]) is how far a projectile travels.

@export_group("Projectile")
## Its root must extend [Projectile].
@export var projectile_scene: PackedScene
## Pixels per second.
@export var projectile_speed: float = 260.0
## Extra enemies a projectile passes through after its first hit.
@export var pierce: int = 0
## Distance from the wielder at which projectiles appear.
@export var spawn_offset: float = 8.0

@export_group("Multi-shot")
@export_range(1, 16) var projectiles_per_shot: int = 1
## Total width of the fan, in degrees, when firing more than one projectile.
@export_range(0.0, 360.0, 1.0) var spread_degrees: float = 0.0

@export_group("Pooling")
## Projectiles created up front. If more are ever in flight at once, the
## pool grows, which costs an instantiation mid-combat.
@export var pool_prewarm: int = 16
