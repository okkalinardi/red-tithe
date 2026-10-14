class_name ShopScreen
extends CanvasLayer
## The shop between waves: random weapons for gold, a reroll, and the two
## weapon slots the player holds.
##
## [method open] rolls the stock for the wave just survived. The game is not
## paused, so HP keeps regenerating; [RunFlow] locks the player's controls
## while the shop is open. Buying:
## - a weapon not held, with a free slot: equips it at the offer's tier;
## - a weapon already held: raises it to its tier + 1 or the offer's tier,
##   whichever is higher ([method WeaponHolder.add_weapon]);
## - a weapon not held, with both slots full: replaces the slot the player
##   picks ([method begin_replace], then [method choose_replace_slot]).
## Rerolling replaces every offer; its cost rises with each use and resets
## at the next shop.

signal closed

enum Purchase {
	## Goes into a free slot.
	NEW,
	## Raises a held copy of the same weapon.
	UPGRADE,
	## Both slots hold other weapons; one must be given up.
	REPLACE,
	## A held copy is already at or above what this offer would give.
	MAXED,
	SOLD,
}

## One weapon for sale.
class Offer:
	extends RefCounted
	var data: WeaponData
	var tier: int = WeaponData.MIN_TIER
	var price: int = 0
	var sold: bool = false

const _DEFAULT_CONFIG: ShopConfig = preload("res://data/shop.tres")

@export var config: ShopConfig = _DEFAULT_CONFIG
## Colour of a price the player cannot pay.
@export var unaffordable_color: Color = Color(1, 0.3, 0.3)
@export var upgrade_color: Color = Color(0.45, 1.0, 0.45)
## Background of each offer card.
@export var card_style: StyleBox

## Replace with a seeded generator to make the stock repeatable in tests.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: Player
var _wave: int = 1
var _offers: Array[Offer] = []
var _rerolls: int = 0
# The offer waiting for the player to pick a slot to replace, or -1.
var _replacing: int = -1
var _offer_cards: Array[Control] = []
var _held_labels: Array[Label] = []
var _replace_buttons: Array[Button] = []

@onready var _gold_label: Label = %GoldLabel
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _held_row: HBoxContainer = %HeldRow
@onready var _offer_row: HBoxContainer = %OfferRow
@onready var _reroll_button: Button = %RerollButton
@onready var _cancel_button: Button = %CancelButton
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	visible = false
	_build_held_slots()
	_build_offer_cards()
	_reroll_button.pressed.connect(reroll)
	_cancel_button.pressed.connect(cancel_replace)
	_continue_button.pressed.connect(close)
	RunState.gold_changed.connect(func(_gold: int) -> void: _refresh())


## Rolls fresh stock for the shop after [param wave] and shows it.
func open(player: Player, wave: int) -> void:
	if _player != player:
		if _player != null and _player.weapons.weapons_changed.is_connected(_refresh):
			_player.weapons.weapons_changed.disconnect(_refresh)
		_player = player
		_player.weapons.weapons_changed.connect(_refresh)
	_wave = maxi(wave, 1)
	_rerolls = 0
	_replacing = -1
	_roll_stock()
	_title_label.text = "SHOP  after wave %d" % _wave
	visible = true
	_refresh()
	_continue_button.grab_focus()
	Events.shop_opened.emit()


func is_open() -> bool:
	return visible


## Hides the shop. Gold not spent is kept.
func close() -> void:
	if not visible:
		return
	_replacing = -1
	visible = false
	Events.shop_closed.emit()
	closed.emit()


func get_offer_count() -> int:
	return _offers.size()


func get_offer(index: int) -> Offer:
	return _offers[index]


## What buying offer [param index] would do now.
func get_purchase(index: int) -> Purchase:
	var offer: Offer = _offers[index]
	if offer.sold:
		return Purchase.SOLD
	var holder: WeaponHolder = _player.weapons
	if holder.find_slot(offer.data) != -1:
		if holder.get_tier_after_duplicate(offer.data, offer.tier) == -1:
			return Purchase.MAXED
		return Purchase.UPGRADE
	if holder.get_free_slot() != -1:
		return Purchase.NEW
	return Purchase.REPLACE


## True if offer [param index] can be bought now (a replace still needs a slot).
func can_buy(index: int) -> bool:
	var purchase: Purchase = get_purchase(index)
	if purchase == Purchase.SOLD or purchase == Purchase.MAXED:
		return false
	return RunState.gold >= _offers[index].price


## Buys offer [param index]. A REPLACE purchase needs [param replace_slot].
## Returns false and spends nothing if the purchase is not possible.
func buy(index: int, replace_slot: int = -1) -> bool:
	if index < 0 or index >= _offers.size() or not can_buy(index):
		return false
	var offer: Offer = _offers[index]
	var holder: WeaponHolder = _player.weapons
	var purchase: Purchase = get_purchase(index)
	if purchase == Purchase.REPLACE and (replace_slot < 0 or replace_slot >= WeaponHolder.SLOT_COUNT):
		return false
	if not RunState.spend_gold(offer.price):
		return false
	offer.sold = true
	if purchase == Purchase.REPLACE:
		holder.equip(replace_slot, offer.data, offer.tier)
	else:
		holder.add_weapon(offer.data, offer.tier)
	_replacing = -1
	_refresh()
	return true


## Starts choosing which held weapon offer [param index] replaces.
func begin_replace(index: int) -> bool:
	if not can_buy(index) or get_purchase(index) != Purchase.REPLACE:
		return false
	_replacing = index
	_refresh()
	return true


## Finishes a replace started by [method begin_replace].
func choose_replace_slot(slot: int) -> bool:
	if _replacing == -1:
		return false
	return buy(_replacing, slot)


func cancel_replace() -> void:
	_replacing = -1
	_refresh()


func is_choosing_replace() -> bool:
	return _replacing != -1


func get_reroll_cost() -> int:
	return config.get_reroll_cost(_wave, _rerolls)


## Pays for and rolls a whole new stock. Returns false if gold is short.
func reroll() -> bool:
	if not RunState.spend_gold(get_reroll_cost()):
		return false
	_rerolls += 1
	_replacing = -1
	_roll_stock()
	_refresh()
	return true


func _roll_stock() -> void:
	_offers.clear()
	if config.weapons.is_empty():
		push_warning("The shop config has no weapons to sell.")
		return
	var min_tier: int = config.get_min_tier(_wave)
	var max_tier: int = config.get_max_tier(_wave)
	for i: int in config.offer_count:
		var offer := Offer.new()
		offer.data = config.weapons[rng.randi_range(0, config.weapons.size() - 1)]
		offer.tier = rng.randi_range(min_tier, max_tier)
		offer.price = config.get_price(offer.data, offer.tier)
		_offers.append(offer)


func _build_held_slots() -> void:
	for slot: int in WeaponHolder.SLOT_COUNT:
		var entry := VBoxContainer.new()
		entry.custom_minimum_size = Vector2(84, 0)
		entry.add_theme_constant_override(&"separation", 0)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 8)
		var button := Button.new()
		button.text = "Replace"
		button.custom_minimum_size = Vector2(0, 14)
		button.pressed.connect(func() -> void: choose_replace_slot(slot))
		entry.add_child(label)
		entry.add_child(button)
		_held_row.add_child(entry)
		_held_labels.append(label)
		_replace_buttons.append(button)


func _build_offer_cards() -> void:
	for i: int in config.offer_count:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(84, 0)
		if card_style != null:
			card.add_theme_stylebox_override(&"panel", card_style)
		var layout := VBoxContainer.new()
		layout.add_theme_constant_override(&"separation", -2)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tier_label := Label.new()
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_size_override(&"font_size", 8)
		var note_label := Label.new()
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_label.add_theme_font_size_override(&"font_size", 8)
		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(0, 14)
		buy_button.pressed.connect(_on_buy_pressed.bind(i))
		for control: Control in [name_label, tier_label, note_label, buy_button]:
			layout.add_child(control)
		card.add_child(layout)
		_offer_row.add_child(card)
		_offer_cards.append(card)


func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	_gold_label.text = "%d gold" % RunState.gold
	var holder: WeaponHolder = _player.weapons
	for slot: int in WeaponHolder.SLOT_COUNT:
		var weapon: Weapon = holder.get_weapon(slot)
		_held_labels[slot].text = "%s  T%d" % [weapon.data.display_name, weapon.tier] if weapon != null else "(empty)"
		_replace_buttons[slot].visible = _replacing != -1
	for i: int in _offer_cards.size():
		_refresh_card(i)
	var reroll_cost: int = get_reroll_cost()
	_reroll_button.text = "Reroll  %dg" % reroll_cost
	_reroll_button.disabled = RunState.gold < reroll_cost or _replacing != -1
	_cancel_button.visible = _replacing != -1
	_continue_button.disabled = _replacing != -1
	if _replacing != -1:
		_hint_label.text = "Pick a weapon to give up for the %s." % _offers[_replacing].data.display_name
	else:
		_hint_label.text = "Buying a weapon you hold upgrades it."


func _refresh_card(index: int) -> void:
	var layout: VBoxContainer = _offer_cards[index].get_child(0) as VBoxContainer
	var name_label: Label = layout.get_child(0) as Label
	var tier_label: Label = layout.get_child(1) as Label
	var note_label: Label = layout.get_child(2) as Label
	var buy_button: Button = layout.get_child(3) as Button
	if index >= _offers.size():
		_offer_cards[index].visible = false
		return
	_offer_cards[index].visible = true
	var offer: Offer = _offers[index]
	name_label.text = offer.data.display_name
	tier_label.text = "Tier %d" % offer.tier
	var purchase: Purchase = get_purchase(index)
	note_label.remove_theme_color_override(&"font_color")
	match purchase:
		Purchase.NEW:
			note_label.text = "New"
		Purchase.UPGRADE:
			var held: Weapon = _player.weapons.get_weapon(_player.weapons.find_slot(offer.data))
			note_label.text = "Upgrade T%d > T%d" % [held.tier, _player.weapons.get_tier_after_duplicate(offer.data, offer.tier)]
			note_label.add_theme_color_override(&"font_color", upgrade_color)
		Purchase.REPLACE:
			note_label.text = "Replaces a weapon"
		Purchase.MAXED:
			note_label.text = "Yours is better"
		Purchase.SOLD:
			note_label.text = "-"
	if purchase == Purchase.SOLD:
		buy_button.text = "Sold"
	else:
		buy_button.text = "Buy  %dg" % offer.price
	buy_button.disabled = not can_buy(index) or _replacing != -1
	if purchase != Purchase.SOLD and RunState.gold < offer.price:
		buy_button.add_theme_color_override(&"font_disabled_color", unaffordable_color)
	else:
		buy_button.remove_theme_color_override(&"font_disabled_color")
	_offer_cards[index].modulate.a = 0.5 if purchase == Purchase.SOLD else 1.0


func _on_buy_pressed(index: int) -> void:
	if get_purchase(index) == Purchase.REPLACE:
		begin_replace(index)
	else:
		buy(index)
