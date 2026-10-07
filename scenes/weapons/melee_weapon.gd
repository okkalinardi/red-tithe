class_name MeleeWeapon
extends Weapon
## Hits every hurtbox inside an arc in front of the wielder. Configured by a
## [MeleeWeaponData]; the Sword is one such data file.
##
## The swing drawn here is a placeholder until the slash effect art exists.

const _ARC_SEGMENTS: int = 12
const _MAX_QUERY_RESULTS: int = 128

var _melee: MeleeWeaponData
var _shape: CircleShape2D = CircleShape2D.new()
var _query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _swing_left: float = 0.0


func setup(weapon_data: WeaponData, stats: StatBlock, start_tier: int = WeaponData.MIN_TIER) -> void:
	super(weapon_data, stats, start_tier)
	_melee = weapon_data as MeleeWeaponData
	if _melee == null:
		push_error("MeleeWeapon needs a MeleeWeaponData, got '%s'." % weapon_data.id)
	_query.shape = _shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	set_process(false)


func _process(delta: float) -> void:
	_swing_left -= delta
	if _swing_left <= 0.0:
		set_process(false)
		queue_redraw()


func _attack(direction: Vector2) -> void:
	if _melee == null:
		return
	_shape.radius = get_range()
	_query.transform = Transform2D(0.0, global_position)
	_query.collision_mask = data.hit_mask
	var half_arc: float = deg_to_rad(_melee.arc_degrees) * 0.5
	var hit_count: int = 0
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in space.intersect_shape(_query, _MAX_QUERY_RESULTS):
		var hurtbox: HurtboxComponent = result.collider as HurtboxComponent
		if hurtbox == null:
			continue
		var to_target: Vector2 = hurtbox.global_position - global_position
		var is_in_arc: bool = absf(direction.angle_to(to_target)) <= half_arc
		if not is_in_arc and to_target.length() > _melee.always_hit_radius:
			continue
		var roll: Weapon.DamageRoll = roll_damage()
		hurtbox.take_hit(roll.damage, roll.is_crit)
		hit_count += 1
		if _melee.max_targets > 0 and hit_count >= _melee.max_targets:
			break
	rotation = direction.angle()
	_swing_left = _melee.swing_time
	set_process(true)
	queue_redraw()


func _draw() -> void:
	if _melee == null or _swing_left <= 0.0:
		return
	var reach: float = get_range()
	if _melee.arc_degrees >= 360.0:
		draw_circle(Vector2.ZERO, reach, _melee.swing_color)
		return
	var half_arc: float = deg_to_rad(_melee.arc_degrees) * 0.5
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i: int in _ARC_SEGMENTS + 1:
		var angle: float = lerpf(-half_arc, half_arc, float(i) / _ARC_SEGMENTS)
		points.append(Vector2.from_angle(angle) * reach)
	draw_colored_polygon(points, _melee.swing_color)
