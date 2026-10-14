extends Node
## Regression test for the shop between waves. Run this scene (F6) and read
## the Output panel. It finishes in about a second.

const _SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _SWORD: WeaponData = preload("res://data/weapons/sword.tres")
const _BOW: WeaponData = preload("res://data/weapons/bow.tres")
const _CONFIG: ShopConfig = preload("res://data/shop.tres")

var _failures: int = 0
var _checks: int = 0
var _player: Player
var _shop: ShopScreen
var _events: Array[String] = []


func _ready() -> void:
	Pools.set_host(self)
	RunState.start_run()
	Events.shop_opened.connect(func() -> void: _events.append("opened"))
	Events.shop_closed.connect(func() -> void: _events.append("closed"))
	_test_config()
	_player = _PLAYER_SCENE.instantiate() as Player
	_player.position = Vector2(6000, 6000)
	add_child(_player)
	_shop = _SHOP_SCENE.instantiate() as ShopScreen
	add_child(_shop)
	await get_tree().physics_frame
	_player.weapons.firing_enabled = false
	_shop.rng.seed = 11
	await _test_open_and_stock()
	_test_upgrade_purchase()
	_test_duplicate_rule()
	_test_new_purchase()
	_test_replace_purchase()
	_test_reroll()
	_test_buttons()
	_test_close()
	print("Shop tests: %d checks, %d failed" % [_checks, _failures])


func _test_config() -> void:
	_check("the shop sells the Sword and the Bow", float(_CONFIG.weapons.has(_SWORD) and _CONFIG.weapons.has(_BOW)), 1.0)
	_check("4 offers", _CONFIG.offer_count, 4)
	_check("after wave 1, up to tier 2", _CONFIG.get_max_tier(1), 2)
	_check("after wave 1, from tier 1", _CONFIG.get_min_tier(1), 1)
	_check("after wave 5, up to tier 6", _CONFIG.get_max_tier(5), 6)
	_check("after wave 5, from tier 4 (top three)", _CONFIG.get_min_tier(5), 4)
	_check("after wave 9, up to tier 10", _CONFIG.get_max_tier(9), 10)
	_check("never above tier 10", _CONFIG.get_max_tier(15), 10)
	_check("price = base x tier", _CONFIG.get_price(_SWORD, 3), _SWORD.base_price * 3)
	_check("first reroll after wave 1 costs 2", _CONFIG.get_reroll_cost(1, 0), 2)
	_check("each reroll costs 2 more", _CONFIG.get_reroll_cost(1, 2), 6)
	_check("rerolls cost more in later waves", _CONFIG.get_reroll_cost(5, 0), 6)


func _test_open_and_stock() -> void:
	_check("the shop starts hidden", float(_shop.is_open()), 0.0)
	_shop.open(_player, 1)
	_check("open shows the shop", float(_shop.is_open()), 1.0)
	_check("Events.shop_opened is emitted", float(str(_events) == str(["opened"])), 1.0)
	_check("the shop does not pause the game", float(get_tree().paused), 0.0)
	_check("4 offers in stock", _shop.get_offer_count(), 4)
	# Many rolls: only the right tiers and weapons, and both weapons appear.
	var tiers_ok: bool = true
	var seen: Dictionary[WeaponData, bool] = {}
	var tiers_seen: Dictionary[int, bool] = {}
	for roll: int in 50:
		_shop.open(_player, 5)
		for i: int in _shop.get_offer_count():
			var offer: ShopScreen.Offer = _shop.get_offer(i)
			tiers_ok = tiers_ok and offer.tier >= 4 and offer.tier <= 6
			tiers_seen[offer.tier] = true
			seen[offer.data] = true
			tiers_ok = tiers_ok and offer.price == _CONFIG.get_price(offer.data, offer.tier) and not offer.sold
	_check("after wave 5 every offer is tier 4-6 at the right price", float(tiers_ok), 1.0)
	_check("all three tiers turn up", tiers_seen.size(), 3)
	_check("both weapons turn up", seen.size(), 2)
	await get_tree().process_frame
	var panel_rect: Rect2 = (_shop.get_node("Root/Center/Panel") as Control).get_global_rect()
	print("INFO  shop panel is %d x %d px" % [panel_rect.size.x, panel_rect.size.y])
	_check("the panel fits on the 480 x 270 screen", float(Rect2(0, 0, 480, 270).encloses(panel_rect)), 1.0)
	_shop.open(_player, 1)


func _set_offer(index: int, data: WeaponData, tier: int) -> ShopScreen.Offer:
	var offer: ShopScreen.Offer = _shop.get_offer(index)
	offer.data = data
	offer.tier = tier
	offer.price = _CONFIG.get_price(data, tier)
	offer.sold = false
	return offer


func _held_tier(data: WeaponData) -> int:
	var slot: int = _player.weapons.find_slot(data)
	return _player.weapons.get_weapon(slot).tier if slot != -1 else -1


func _test_upgrade_purchase() -> void:
	_check("the player starts with a tier 1 Sword", _held_tier(_SWORD), 1)
	var offer: ShopScreen.Offer = _set_offer(0, _SWORD, 1)
	_check("a held weapon is an upgrade", _shop.get_purchase(0), ShopScreen.Purchase.UPGRADE)
	_check("with no gold it cannot be bought", float(_shop.can_buy(0)), 0.0)
	_check("buying without gold fails", float(_shop.buy(0)), 0.0)
	_check("and changes nothing", _held_tier(_SWORD), 1)
	RunState.add_gold(offer.price + 5)
	_check("with gold it can be bought", float(_shop.can_buy(0)), 1.0)
	_check("buying works", float(_shop.buy(0)), 1.0)
	_check("a tier 1 duplicate raises the Sword to tier 2", _held_tier(_SWORD), 2)
	_check("the price was paid", RunState.gold, 5)
	_check("the offer is sold", _shop.get_purchase(0), ShopScreen.Purchase.SOLD)
	RunState.add_gold(500)
	_check("a sold offer cannot be bought again", float(_shop.buy(0)), 0.0)


func _test_duplicate_rule() -> void:
	_set_offer(1, _SWORD, 6)
	_shop.buy(1)
	_check("a higher-tier duplicate jumps to its tier", _held_tier(_SWORD), 6)
	_set_offer(1, _SWORD, 3)
	_shop.buy(1)
	_check("a lower-tier duplicate still gives +1", _held_tier(_SWORD), 7)
	_player.weapons.get_weapon(_player.weapons.find_slot(_SWORD)).set_tier(10)
	_set_offer(1, _SWORD, 4)
	_check("a duplicate of a tier 10 weapon is no use", _shop.get_purchase(1), ShopScreen.Purchase.MAXED)
	var gold: int = RunState.gold
	_check("so it cannot be bought", float(_shop.buy(1)), 0.0)
	_check("and costs nothing", RunState.gold, gold)


func _test_new_purchase() -> void:
	_player.weapons.unequip(_player.weapons.find_slot(_BOW))
	_set_offer(2, _BOW, 3)
	_check("a weapon not held, with a free slot, is new", _shop.get_purchase(2), ShopScreen.Purchase.NEW)
	_shop.buy(2)
	_check("it is equipped at the offer's tier", _held_tier(_BOW), 3)


func _test_replace_purchase() -> void:
	var dagger: WeaponData = _SWORD.duplicate() as WeaponData
	dagger.id = &"dagger"
	dagger.display_name = "Dagger"
	_set_offer(3, dagger, 2)
	_check("with both slots full, a new weapon must replace one", _shop.get_purchase(3), ShopScreen.Purchase.REPLACE)
	var gold: int = RunState.gold
	_check("buying it without a slot fails", float(_shop.buy(3)), 0.0)
	_check("and costs nothing", RunState.gold, gold)
	_check("begin_replace starts choosing", float(_shop.begin_replace(3)), 1.0)
	_check("choosing", float(_shop.is_choosing_replace()), 1.0)
	_check("continue is blocked while choosing", float((_shop.get_node("%ContinueButton") as Button).disabled), 1.0)
	var replace_button: Button = _shop.get_node("%HeldRow").get_child(0).get_child(1) as Button
	_check("the held weapons offer a Replace button", float(replace_button.visible), 1.0)
	_shop.cancel_replace()
	_check("cancel stops choosing", float(_shop.is_choosing_replace()), 0.0)
	_check("and hides the Replace buttons", float(replace_button.visible), 0.0)
	_shop.begin_replace(3)
	var sword_slot: int = _player.weapons.find_slot(_SWORD)
	(_shop.get_node("%HeldRow").get_child(sword_slot).get_child(1) as Button).pressed.emit()
	_check("the Dagger took the Sword's slot", float(_player.weapons.get_weapon(sword_slot).data == dagger), 1.0)
	_check("at tier 2", _player.weapons.get_weapon(sword_slot).tier, 2)
	_check("the Sword is gone", _player.weapons.find_slot(_SWORD), -1)
	_check("the price was paid", RunState.gold, gold - _CONFIG.get_price(dagger, 2))
	_check("choosing is over", float(_shop.is_choosing_replace()), 0.0)
	# Put the Sword back for the rest of the test.
	_player.weapons.equip(sword_slot, _SWORD, 1)


func _test_reroll() -> void:
	RunState.gold = 0
	RunState.add_gold(1)
	_check("a reroll without enough gold fails", float(_shop.reroll()), 0.0)
	RunState.add_gold(20)
	var before: ShopScreen.Offer = _shop.get_offer(0)
	_check("the first reroll costs 2", _shop.get_reroll_cost(), 2)
	_check("a reroll works", float(_shop.reroll()), 1.0)
	_check("it cost 2", RunState.gold, 19)
	_check("the stock is new", float(_shop.get_offer(0) != before), 1.0)
	_check("nothing in it is sold", float(_shop.get_purchase(0) != ShopScreen.Purchase.SOLD), 1.0)
	_check("the next reroll costs 4", _shop.get_reroll_cost(), 4)
	_shop.reroll()
	_check("then 6", _shop.get_reroll_cost(), 6)
	_shop.open(_player, 1)
	_check("the next shop starts at the base cost again", _shop.get_reroll_cost(), 2)


func _test_buttons() -> void:
	RunState.gold = 0
	RunState.add_gold(1000)
	var card: Control = _shop.get_node("%OfferRow").get_child(0) as Control
	var buy_button: Button = card.get_child(0).get_child(3) as Button
	var offer: ShopScreen.Offer = _set_offer(0, _BOW, 2)
	_shop.cancel_replace()
	_check("the card shows the price", float(buy_button.text == "Buy  %dg" % offer.price), 1.0)
	var note: Label = card.get_child(0).get_child(2) as Label
	_check("the card says what buying does", float(note.text.begins_with("Upgrade T")), 1.0)
	buy_button.pressed.emit()
	_check("the Buy button buys", float(_shop.get_purchase(0) == ShopScreen.Purchase.SOLD), 1.0)
	_check("a sold card says so", float(buy_button.text == "Sold" and buy_button.disabled), 1.0)
	var gold_label: Label = _shop.get_node("%GoldLabel") as Label
	_check("gold is shown", float(gold_label.text == "%d gold" % RunState.gold), 1.0)
	RunState.gold = 0
	RunState.add_gold(0)
	_set_offer(1, _BOW, 5)
	_shop.cancel_replace()
	var other: Button = _shop.get_node("%OfferRow").get_child(1).get_child(0).get_child(3) as Button
	_check("an unaffordable offer's button is off", float(other.disabled), 1.0)
	_check("the reroll button is off without gold", float((_shop.get_node("%RerollButton") as Button).disabled), 1.0)


func _test_close() -> void:
	var closed: Array[int] = [0]
	_shop.closed.connect(func() -> void: closed[0] += 1)
	_events.clear()
	(_shop.get_node("%ContinueButton") as Button).pressed.emit()
	_check("continue closes the shop", float(_shop.is_open()), 0.0)
	_check("closed is emitted", closed[0], 1)
	_check("Events.shop_closed is emitted", float(str(_events) == str(["closed"])), 1.0)
	_shop.close()
	_check("closing twice does nothing", closed[0], 1)


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])
