class_name ProjectileWeapon
extends Weapon
## Fires pooled projectiles along the aim. Configured by a
## [ProjectileWeaponData]; the Bow is one such data file.

var _ranged: ProjectileWeaponData


func setup(weapon_data: WeaponData, stats: StatBlock, start_tier: int = WeaponData.MIN_TIER) -> void:
	super(weapon_data, stats, start_tier)
	_ranged = weapon_data as ProjectileWeaponData
	if _ranged == null or _ranged.projectile_scene == null:
		push_error("ProjectileWeapon needs a ProjectileWeaponData with a projectile scene, got '%s'." % weapon_data.id)
		_ranged = null
		return
	Pools.prewarm(_ranged.projectile_scene, _ranged.pool_prewarm)


func _attack(direction: Vector2) -> void:
	if _ranged == null:
		return
	var count: int = _ranged.projectiles_per_shot
	var spread: float = deg_to_rad(_ranged.spread_degrees)
	for i: int in count:
		# Spread the shots evenly across the fan; a single shot goes straight.
		var offset: float = 0.0
		if count > 1:
			offset = lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
		var shot_direction: Vector2 = direction.rotated(offset)
		var projectile: Projectile = Pools.acquire(_ranged.projectile_scene) as Projectile
		if projectile == null:
			return
		projectile.launch(
			global_position + shot_direction * _ranged.spawn_offset,
			shot_direction,
			_ranged.projectile_speed,
			get_range(),
			_ranged.pierce,
			_on_projectile_hit,
		)


func _on_projectile_hit(hurtbox: HurtboxComponent) -> void:
	var roll: Weapon.DamageRoll = roll_damage()
	hurtbox.take_hit(roll.damage, roll.is_crit)
