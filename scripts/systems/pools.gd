class_name Pools
extends Object
## One shared [ObjectPool] per scene, created on demand.
## [codeblock]
## Pools.prewarm(arrow_scene, 16)            # at setup, before combat
## var arrow := Pools.acquire(arrow_scene)   # instead of instantiate()
## Pools.release(arrow)                      # instead of queue_free()
## [/codeblock]
## The pools live under a "Pools" node inside the host (the gameplay scene
## calls [method set_host] with itself), so they are drawn with the game
## world and are freed with it. Without a host, the current scene is used.

const _POOL_META: StringName = &"object_pool"
const _CONTAINER_NAME: String = "Pools"

static var _pools: Dictionary[PackedScene, ObjectPool] = {}
static var _container: Node
static var _host: Node


## Creates [param count] instances ahead of time, so nothing is instantiated
## in the middle of combat. Runs at the end of the frame, which makes it safe
## to call from _ready.
static func prewarm(scene: PackedScene, count: int) -> void:
	(func() -> void: get_pool(scene).prewarm(count)).call_deferred()


## An instance of [param scene], or null if its pool is at its limit.
static func acquire(scene: PackedScene) -> Node:
	return get_pool(scene).acquire()


## Returns [param node] to the pool it came from. A node that did not come
## from a pool is freed instead.
static func release(node: Node) -> void:
	if not node.has_meta(_POOL_META):
		node.queue_free()
		return
	var pool: ObjectPool = node.get_meta(_POOL_META) as ObjectPool
	if is_instance_valid(pool):
		pool.release(node)
	else:
		node.queue_free()


## Forgets every pool. Call before reloading the scene: the pools are freed
## with it, and new ones are made on demand in the new scene.
static func clear() -> void:
	_pools.clear()
	_container = null
	_host = null


## Makes [param host] the owner of every pool from now on, forgetting any
## pools made before. The gameplay scene calls this first thing in _ready.
static func set_host(host: Node) -> void:
	clear()
	_host = host


## The pool for [param scene]. Use it to set [member ObjectPool.max_size] or
## to read counts.
static func get_pool(scene: PackedScene) -> ObjectPool:
	var pool: ObjectPool = _pools.get(scene)
	if is_instance_valid(pool):
		return pool
	pool = ObjectPool.new()
	pool.scene = scene
	pool.name = scene.resource_path.get_file().get_basename().to_pascal_case() + "Pool"
	pool.child_entered_tree.connect(func(node: Node) -> void: node.set_meta(_POOL_META, pool))
	_get_container().add_child(pool)
	_pools[scene] = pool
	return pool


static func _get_container() -> Node:
	if is_instance_valid(_container):
		return _container
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Node = _host
	if not is_instance_valid(host):
		host = tree.current_scene if tree.current_scene != null else tree.root
	_container = Node.new()
	_container.name = _CONTAINER_NAME
	host.add_child(_container)
	return _container
