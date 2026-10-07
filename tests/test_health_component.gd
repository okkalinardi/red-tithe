extends Node
## Regression test for HealthComponent and its wiring into the player.
## Run this scene (F6) and read the Output panel. Time is simulated by calling
## _physics_process by hand, so the test finishes at once.

const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _failures: int = 0
var _checks: int = 0
var _damaged_total: int = 0
var _died_count: int = 0
var _changed_count: int = 0
var _player_died_count: int = 0


func _ready() -> void:
	_test_basic_damage()
	_test_defense_and_stats()
	_test_regen()
	_test_invincibility()
	_test_spend_hp()
	_test_death()
	_test_lethal_hit_handler()
	_test_hit_flash()
	await _test_player_wiring()
	print("HealthComponent tests: %d checks, %d failed" % [_checks, _failures])


func _new_health(stats: StatBlock = null) -> HealthComponent:
	var health := HealthComponent.new()
	add_child(health)
	# The test advances time itself.
	health.set_physics_process(false)
	if stats != null:
		health.bind_stats(stats)
	_damaged_total = 0
	_died_count = 0
	_changed_count = 0
	health.damaged.connect(func(amount: int) -> void: _damaged_total += amount)
	health.died.connect(func() -> void: _died_count += 1)
	health.health_changed.connect(func(_hp: float, _max: int) -> void: _changed_count += 1)
	return health


func _new_stats() -> StatBlock:
	var stats := StatBlock.new()
	stats.config = StatConfig.new()
	return stats


func _advance(health: HealthComponent, seconds: float) -> void:
	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < seconds - 0.0001:
		health._physics_process(step)
		elapsed += step


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _test_basic_damage() -> void:
	var h: HealthComponent = _new_health()
	_check("default max_hp", h.max_hp, 100)
	_check("starts full", h.current_hp, 100)
	_check("hit returns damage dealt", h.take_damage(30.0), 30)
	_check("hp after hit", h.current_hp, 70)
	_check("damaged signal carries the amount", _damaged_total, 30)
	_check("health_changed emitted", _changed_count, 1)
	_check("hp ratio", h.get_hp_ratio(), 0.7)
	_check("tiny hit still deals 1", h.take_damage(0.2), 1)
	_check("zero damage is ignored", h.take_damage(0.0), 0)
	_check("negative damage is ignored", h.take_damage(-5.0), 0)
	_check("heal returns amount restored", h.heal(10.0), 10)
	_check("heal stops at max", h.heal(500.0), 21)
	_check("hp is full again", h.current_hp, 100)


func _test_defense_and_stats() -> void:
	var stats: StatBlock = _new_stats()
	stats.vitality = 25
	stats.strength = 50
	var h: HealthComponent = _new_health(stats)
	_check("max_hp from VIT", h.max_hp, 250)
	_check("bind_stats fills hp", h.current_hp, 250)
	_check("STR 50 halves the hit", h.take_damage(20.0), 10)
	_check("hp after defended hit", h.current_hp, 240)
	stats.vitality = 30
	_check("max_hp follows a stat change", h.max_hp, 280)
	_check("raising max_hp does not heal", h.current_hp, 240)
	stats.vitality = 0
	_check("lowering max_hp clamps hp", h.current_hp, 100)


func _test_regen() -> void:
	var stats: StatBlock = _new_stats()
	var h: HealthComponent = _new_health(stats)
	h.take_damage(50.0)
	_changed_count = 0
	_advance(h, 1.0)
	_check("regen 2 HP/s at VIT 0", h.current_hp, 52.0, 0.01)
	_check("health_changed far less often than every frame", float(_changed_count <= 3), 1.0)
	stats.vitality = 50
	h.take_damage(10.0)
	var before: float = h.current_hp
	_advance(h, 1.0)
	_check("regen 7 HP/s at VIT 50", h.current_hp - before, 7.0, 0.01)
	_advance(h, 120.0)
	_check("regen stops at max", h.current_hp, 400)
	var enemy: HealthComponent = _new_health()
	enemy.take_damage(10.0)
	_advance(enemy, 5.0)
	_check("no regen without stats by default", enemy.current_hp, 90)


func _test_invincibility() -> void:
	var h: HealthComponent = _new_health()
	h.invincibility_time = 0.5
	_check("first hit lands", h.take_damage(10.0), 10)
	_check("invincible after a hit", float(h.is_invincible()), 1.0)
	_check("second hit is ignored", h.take_damage(10.0), 0)
	_advance(h, 0.4)
	_check("still invincible at 0.4 s", h.take_damage(10.0), 0)
	_advance(h, 0.15)
	_check("vulnerable after 0.5 s", h.take_damage(10.0), 10)
	_check("hp after two landed hits", h.current_hp, 80)
	var enemy: HealthComponent = _new_health()
	enemy.take_damage(10.0)
	_check("no i-frames by default", enemy.take_damage(10.0), 10)


func _test_spend_hp() -> void:
	var stats: StatBlock = _new_stats()
	stats.strength = 50
	var h: HealthComponent = _new_health(stats)
	h.invincibility_time = 0.5
	h.take_damage(160.0)
	_check("hp before spending", h.current_hp, 20)
	_damaged_total = 0
	_check("spend works during i-frames", float(h.spend_hp(10.0)), 1.0)
	_check("defense does not reduce a cost", h.current_hp, 10)
	_check("spend does not emit damaged", _damaged_total, 0)
	_check("cost equal to hp is refused", float(h.spend_hp(10.0)), 0.0)
	_check("cost leaving under 1 hp is refused", float(h.spend_hp(9.5)), 0.0)
	_check("refused cost spends nothing", h.current_hp, 10)
	_check("can_spend agrees", float(h.can_spend(9.0)), 1.0)
	_check("cost leaving exactly 1 hp is allowed", float(h.spend_hp(9.0)), 1.0)
	_check("hp after spending", h.current_hp, 1)
	_check("free skill always castable", float(h.spend_hp(0.0)), 1.0)
	_check("spend never kills", float(h.is_alive()), 1.0)


func _test_death() -> void:
	var h: HealthComponent = _new_health()
	h.base_hp_regen = 5.0
	h.take_damage(999.0)
	_check("hp is 0", h.current_hp, 0)
	_check("died emitted once", _died_count, 1)
	_check("not alive", float(h.is_alive()), 0.0)
	_check("dead takes no damage", h.take_damage(10.0), 0)
	_check("died not emitted twice", _died_count, 1)
	_check("dead cannot heal", h.heal(10.0), 0)
	_check("dead cannot spend", float(h.spend_hp(1.0)), 0.0)
	_advance(h, 2.0)
	_check("dead does not regen", h.current_hp, 0)
	h.restore_full()
	_check("restore_full revives", float(h.is_alive()), 1.0)
	_check("restore_full fills hp", h.current_hp, 100)


func _test_lethal_hit_handler() -> void:
	var h: HealthComponent = _new_health()
	h.invincibility_time = 0.5
	var saves: Array[int] = [1]
	h.lethal_hit_handler = func() -> bool:
		if saves[0] <= 0:
			return false
		saves[0] -= 1
		return true
	h.take_damage(50.0)
	_check("handler not used on a normal hit", saves[0], 1)
	_advance(h, 0.6)
	h.take_damage(999.0)
	_check("survives the lethal hit at 1 hp", h.current_hp, 1, 0.1)
	_check("did not die", _died_count, 0)
	_check("invincible after the save", float(h.is_invincible()), 1.0)
	_advance(h, 0.6)
	h.take_damage(999.0)
	_check("dies when the handler refuses", _died_count, 1)


func _test_hit_flash() -> void:
	var sprite := Sprite2D.new()
	add_child(sprite)
	var h: HealthComponent = _new_health()
	h.flash_target = sprite
	h.take_damage(5.0)
	_check("flash material applied on hit", float(sprite.material is ShaderMaterial), 1.0)
	_advance(h, 0.05)
	_check("still flashing at 0.05 s", float(sprite.material != null), 1.0)
	_advance(h, 0.1)
	_check("material restored after the flash", float(sprite.material == null), 1.0)
	var own_material := CanvasItemMaterial.new()
	sprite.material = own_material
	h.take_damage(5.0)
	h.take_damage(5.0)
	_advance(h, 0.2)
	_check("the sprite's own material is put back", float(sprite.material == own_material), 1.0)
	sprite.queue_free()


func _test_player_wiring() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	var sprite: AnimatedSprite2D = player.get_node("Sprite") as AnimatedSprite2D
	Events.player_died.connect(func() -> void: _player_died_count += 1)
	_check("player has 100 hp", player.health.max_hp, 100)
	player.stats.vitality = 10
	_check("player max_hp follows VIT", player.health.max_hp, 160)
	_check("player has i-frames", player.health.invincibility_time, 0.5)
	_check("player flash target is its sprite", float(player.health.flash_target == sprite), 1.0)
	player.health.take_damage(20.0)
	_check("player took the hit", player.health.current_hp, 80, 0.5)
	_check("player sprite flashes", float(sprite.material is ShaderMaterial), 1.0)
	for i: int in 40:
		await get_tree().physics_frame
	_check("player flash ended", float(sprite.material == null), 1.0)
	_check("player i-frames ended", float(player.health.is_invincible()), 0.0)
	player.health.take_damage(9999.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check("player_died event emitted once", _player_died_count, 1)
	_check("dead animation plays", float(sprite.animation == &"dead"), 1.0)
	_check("dead player stops moving", float(player.is_physics_processing()), 0.0)
	player.queue_free()
