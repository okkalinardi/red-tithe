class_name Arena
extends Node2D
## The play area: a painted floor, obstacles, and invisible walls on all four
## sides.
##
## Paint the Floor and Obstacles layers in the editor. Obstacles block the
## player, enemies and projectiles through the tile set's physics layer, which
## is on the "world" layer; any tile with a collision polygon blocks.
## [member size_in_tiles] is the single source of truth for the walls and the
## camera limits, so keep the painted floor the same size.
## The node's origin is the arena's top-left corner.

const TILE_SIZE: int = 16

@export var size_in_tiles: Vector2i = Vector2i(60, 34)

@onready var floor_layer: TileMapLayer = $Floor
@onready var obstacle_layer: TileMapLayer = $Obstacles


func _ready() -> void:
	_build_walls()
	var painted: Rect2i = floor_layer.get_used_rect()
	if painted != Rect2i(Vector2i.ZERO, size_in_tiles):
		push_warning("Arena floor covers %s but size_in_tiles is %s." % [painted, size_in_tiles])


## The arena rectangle in world space, in pixels.
func get_bounds() -> Rect2i:
	return Rect2i(Vector2i(global_position), size_in_tiles * TILE_SIZE)


## True if a circle of [param clearance] pixels around [param point] is inside
## the arena and touches no obstacle tile. Used to keep spawns out of
## obstacles.
func is_point_free(point: Vector2, clearance: float = 0.0) -> bool:
	if not Rect2(get_bounds()).grow(-clearance).has_point(point):
		return false
	var reach: Vector2 = Vector2(clearance, clearance)
	var first: Vector2i = obstacle_layer.local_to_map(obstacle_layer.to_local(point - reach))
	var last: Vector2i = obstacle_layer.local_to_map(obstacle_layer.to_local(point + reach))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			if obstacle_layer.get_cell_source_id(Vector2i(x, y)) != -1:
				return false
	return true


## Every cell that holds an obstacle tile.
func get_obstacle_cells() -> Array[Vector2i]:
	return obstacle_layer.get_used_cells()


## The world-space centre of a cell of the obstacle layer.
func cell_to_world(cell: Vector2i) -> Vector2:
	return obstacle_layer.to_global(obstacle_layer.map_to_local(cell))


func _build_walls() -> void:
	var size: Vector2 = size_in_tiles * TILE_SIZE
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = PhysicsLayers.WORLD
	walls.collision_mask = 0
	add_child(walls)
	# Each boundary is an infinite line; the normal points into the arena.
	_add_boundary(walls, Vector2.ZERO, Vector2.RIGHT)
	_add_boundary(walls, Vector2.ZERO, Vector2.DOWN)
	_add_boundary(walls, size, Vector2.LEFT)
	_add_boundary(walls, size, Vector2.UP)


func _add_boundary(body: StaticBody2D, point: Vector2, inward_normal: Vector2) -> void:
	var boundary := WorldBoundaryShape2D.new()
	boundary.normal = inward_normal
	var shape := CollisionShape2D.new()
	shape.shape = boundary
	shape.position = point
	body.add_child(shape)
