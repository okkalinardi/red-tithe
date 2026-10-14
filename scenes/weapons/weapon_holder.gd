class_name WeaponHolder
extends Node2D
## The weapons a character holds: two slots that fire automatically towards
## [member aim_direction].
##
## The owner calls [method setup] once and keeps [member aim_direction]
## up to date. The shop calls [method add_weapon].

## Emitted when a weapon is equipped, removed or upgraded. For the HUD and shop.
signal weapons_changed

const SLOT_COUNT: int = 2

## Weapons held at the start of a run.
@export var starting_weapons: Array[WeaponData] = []

## Unit vector the weapons fire along.
var aim_direction: Vector2 = Vector2.RIGHT
## Set to false to hold fire (death, shop, menus).
var firing_enabled: bool = true

var _stats: StatBlock
var _slots: Array[Weapon] = []


func _init() -> void:
	_slots.resize(SLOT_COUNT)


func _physics_process(delta: float) -> void:
	for weapon: Weapon in _slots:
		if weapon != null:
			weapon.tick(delta, aim_direction, firing_enabled)


## [param stats] scales every weapon held. Equips the starting weapons.
func setup(stats: StatBlock) -> void:
	_stats = stats
	for weapon_data: WeaponData in starting_weapons:
		add_weapon(weapon_data)


## The shop rule. A duplicate raises the held weapon to its tier + 1 or to
## [param tier], whichever is higher; a new weapon goes into a free slot at
## [param tier]. Returns false if nothing changed (both slots taken by other
## weapons, or the held weapon cannot go higher).
func add_weapon(weapon_data: WeaponData, tier: int = WeaponData.MIN_TIER) -> bool:
	var held_slot: int = find_slot(weapon_data)
	if held_slot != -1:
		var new_tier: int = get_tier_after_duplicate(weapon_data, tier)
		if new_tier == -1:
			return false
		_slots[held_slot].set_tier(new_tier)
		weapons_changed.emit()
		return true
	var free_slot: int = get_free_slot()
	if free_slot == -1:
		return false
	equip(free_slot, weapon_data, tier)
	return true


## The tier a held [param weapon_data] would reach if a copy at [param tier]
## were added, or -1 if it is not held or cannot go higher.
func get_tier_after_duplicate(weapon_data: WeaponData, tier: int = WeaponData.MIN_TIER) -> int:
	var held_slot: int = find_slot(weapon_data)
	if held_slot == -1:
		return -1
	var held_tier: int = _slots[held_slot].tier
	var new_tier: int = mini(maxi(held_tier + 1, tier), WeaponData.MAX_TIER)
	return new_tier if new_tier > held_tier else -1


## Puts a weapon in [param slot], replacing whatever was there.
func equip(slot: int, weapon_data: WeaponData, tier: int = WeaponData.MIN_TIER) -> Weapon:
	if _stats == null:
		push_error("WeaponHolder.setup() must be called before equipping.")
		return null
	_remove(slot)
	var weapon: Weapon
	if weapon_data.weapon_scene != null:
		weapon = weapon_data.weapon_scene.instantiate() as Weapon
		if weapon == null:
			push_error("The scene of weapon '%s' does not extend Weapon." % weapon_data.id)
			return null
	else:
		weapon = Weapon.new()
	weapon.setup(weapon_data, _stats, tier)
	_slots[slot] = weapon
	add_child(weapon)
	weapons_changed.emit()
	return weapon


func unequip(slot: int) -> void:
	if _slots[slot] == null:
		return
	_remove(slot)
	weapons_changed.emit()


## The weapon in [param slot], or null if the slot is empty.
func get_weapon(slot: int) -> Weapon:
	return _slots[slot]


## The slot holding [param weapon_data], or -1.
func find_slot(weapon_data: WeaponData) -> int:
	for slot: int in SLOT_COUNT:
		if _slots[slot] != null and _slots[slot].data == weapon_data:
			return slot
	return -1


## The first empty slot, or -1.
func get_free_slot() -> int:
	return _slots.find(null)


func _remove(slot: int) -> void:
	if _slots[slot] != null:
		_slots[slot].queue_free()
		_slots[slot] = null
