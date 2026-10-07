class_name WeaponData
extends Resource
## Everything that defines one kind of weapon. One .tres file per weapon in
## res://data/weapons/.
##
## The tier is not stored here: it belongs to the weapon the player is
## holding (see [Weapon]). This resource only says how a tier changes the
## numbers.

const MIN_TIER: int = 1
const MAX_TIER: int = 10

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
## The scene that performs the attack. Its root must extend [Weapon].
@export var weapon_scene: PackedScene

@export_group("Base values (tier 1, no stats)")
@export var base_damage: float = 10.0
## Seconds between attacks.
@export_range(0.05, 10.0, 0.01) var base_cooldown: float = 1.0
## Pixels. Swing radius for melee, travel distance for projectiles.
@export var base_range: float = 32.0

@export_group("Stat scaling")
## How much each stat counts towards this weapon's damage.
## Sword (1, 0), Bow (0, 1), Dagger (0.5, 0.5).
@export_range(0.0, 1.0, 0.05) var strength_weight: float = 1.0
@export_range(0.0, 1.0, 0.05) var dexterity_weight: float = 0.0

@export_group("Targets")
## Physics layers this weapon can hit.
@export_flags_2d_physics var hit_mask: int = PhysicsLayers.ENEMY

@export_group("Tier scaling")
## Extra damage per tier above 1. 0.2 = +20% of base damage per tier.
@export var damage_growth_per_tier: float = 0.2


## Damage at [param tier], before stats and crit.
func get_damage(tier: int) -> float:
	var steps: int = clampi(tier, MIN_TIER, MAX_TIER) - MIN_TIER
	return base_damage * (1.0 + damage_growth_per_tier * steps)
