class_name Arena
extends Node2D
## The play area. Its size is the single source of truth for the boundary
## walls and for the camera limits.
##
## The node's origin is the arena's top-left corner. The floor drawn here is
## a placeholder until the tileset exists.

const TILE_SIZE: int = 16
const _FLOOR_COLOR: Color = Color(0.13, 0.13, 0.16)
const _GRID_COLOR: Color = Color(0.2, 0.2, 0.24)
const _BORDER_COLOR: Color = Color(0.55, 0.12, 0.14)
const _GRID_STEP_TILES: int = 2

@export var size_in_tiles: Vector2i = Vector2i(60, 34)


func _ready() -> void:
	_build_walls()
	queue_redraw()


## The arena rectangle in world space, in pixels.
func get_bounds() -> Rect2i:
	return Rect2i(Vector2i(global_position), size_in_tiles * TILE_SIZE)


func _build_walls() -> void:
	var size: Vector2 = size_in_tiles * TILE_SIZE
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	# Layer 1 is "world". Walls detect nothing themselves.
	walls.collision_layer = 1
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


func _draw() -> void:
	var size: Vector2 = size_in_tiles * TILE_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), _FLOOR_COLOR)
	var step: float = TILE_SIZE * _GRID_STEP_TILES
	var x: float = step
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), _GRID_COLOR)
		x += step
	var y: float = step
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), _GRID_COLOR)
		y += step
	draw_rect(Rect2(Vector2.ZERO, size), _BORDER_COLOR, false, 2.0)
