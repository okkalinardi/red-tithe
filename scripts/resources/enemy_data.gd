class_name EnemyData
extends Resource
## Everything that defines one kind of enemy. One .tres file per enemy in
## res://data/enemies/.
##
## The shared enemy scene reads all of this when an enemy is spawned, so a
## new chasing enemy needs no code and no new scene.

@export var id: StringName
@export var display_name: String = ""
## The scene to spawn. Its root must extend [Enemy]. Use
## res://scenes/enemies/enemy.tscn for a plain chaser.
@export var scene: PackedScene

@export_group("Stats")
@export var max_hp: int = 20
## Pixels per second.
@export var move_speed: float = 50.0
## Damage of one touch, before the target's defense.
@export var contact_damage: float = 8.0
## Seconds before the same target can be touched again.
@export var contact_interval: float = 0.5

@export_group("Rewards")
@export var xp_reward: int = 1
@export var gold_reward: int = 1

@export_group("Body (pixels)")
## Collision with walls and obstacles.
@export var body_radius: float = 5.0
## The area the player's attacks can hit.
@export var hurtbox_radius: float = 7.0
## The area that hurts the player on touch.
@export var contact_radius: float = 6.0

@export_group("Swarm")
## Enemies closer than this push each other apart.
@export var separation_radius: float = 14.0
## How hard they push, as a share of move speed. 0 turns separation off.
@export_range(0.0, 3.0, 0.05) var separation_strength: float = 1.0
## Stops walking this close to the target, so it does not jitter on top of it.
@export var stop_distance: float = 4.0

@export_group("Visuals")
## Animations named walk_down, walk_up, walk_left and walk_right are played
## to match the direction of travel. Any that are missing are skipped.
@export var sprite_frames: SpriteFrames
@export var visual_scale: float = 1.0
## Moves the sprite so the body sits on the enemy's position. In sprite pixels.
@export var sprite_offset: Vector2 = Vector2.ZERO
## Tick this for a sheet that only has a side view drawn facing left. The
## sprite is then mirrored to face right.
@export var sprite_faces_left: bool = false
