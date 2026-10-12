class_name ObjectPool
extends Node
## Reuses instances of one scene instead of creating and freeing them.
##
## Instances are children of this node. Because the pool is a plain Node,
## 2D instances are positioned in world space no matter where the pool sits.
## A released instance is hidden and fully disabled (no processing, no
## physics) until it is acquired again.
##
## Most code should go through [Pools] instead of creating pools by hand.

## The scene this pool hands out.
@export var scene: PackedScene
## Instances created up front by [method prewarm] in [method _ready].
@export var initial_size: int = 0
## Hard limit on instances, in use or not. 0 means no limit.
@export var max_size: int = 0

var _free: Array[Node] = []
var _active: Dictionary[Node, bool] = {}


func _ready() -> void:
	prewarm(initial_size)


## Makes sure at least [param count] instances exist.
func prewarm(count: int) -> void:
	while get_total_count() < count and not _is_at_limit():
		_free.append(_create())


## Returns a ready-to-use instance, or null if [member max_size] is reached.
## The caller must reset the instance's own state (position, timers).
func acquire() -> Node:
	var node: Node
	if not _free.is_empty():
		node = _free.pop_back()
	elif _is_at_limit():
		return null
	else:
		node = _create()
	_active[node] = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	return node


## Hands an instance back. Safe to call from physics callbacks and safe to
## call twice.
func release(node: Node) -> void:
	if not _active.erase(node):
		return
	# Deferred: physics objects cannot be disabled while a collision is
	# being reported.
	_finish_release.call_deferred(node)


func get_active_count() -> int:
	return _active.size()


## Instances that exist, in use or not.
func get_total_count() -> int:
	return get_child_count()


func _is_at_limit() -> bool:
	return max_size > 0 and get_total_count() >= max_size


func _create() -> Node:
	var node: Node = scene.instantiate()
	_disable(node)
	add_child(node)
	return node


func _finish_release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_disable(node)
	_free.append(node)


func _disable(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
