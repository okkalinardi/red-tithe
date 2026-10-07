class_name HurtboxComponent
extends Area2D
## The area of a character that attacks can hit. It passes hits on to a
## [HealthComponent].
##
## Add a CollisionShape2D child, point [member health] at the health node,
## and put this area on the layer of its side: [constant PhysicsLayers.ENEMY]
## for enemies, [constant PhysicsLayers.PLAYER] for the player. Attacks find
## it through their collision mask and call [method take_hit].

## Emitted for every hit that lands, after defense. For damage numbers.
signal hit_taken(amount: int, is_crit: bool)

@export var health: HealthComponent


func _ready() -> void:
	# A hurtbox is only ever detected; it detects nothing itself. Its layer
	# is chosen by the scene that uses it. (Do not set defaults in _init:
	# Godot runs _init after it has applied the scene's own values.)
	collision_mask = 0
	monitoring = false


## Applies a hit and returns the damage dealt after defense (0 if ignored).
func take_hit(damage: float, is_crit: bool = false) -> int:
	if health == null:
		push_error("HurtboxComponent '%s' has no HealthComponent." % get_path())
		return 0
	var dealt: int = health.take_damage(damage)
	if dealt > 0:
		hit_taken.emit(dealt, is_crit)
	return dealt
