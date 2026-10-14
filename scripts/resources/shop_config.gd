class_name ShopConfig
extends Resource
## What the shop between waves sells and what it costs. Edit
## [code]res://data/shop.tres[/code] in the inspector to rebalance.
##
## The shop after wave N sells weapons up to tier N + [member tier_cap_above_wave]
## (at most 10). Each offer's tier is rolled from the top
## [member tier_window] tiers on sale. Price = weapon base price x tier x
## [member price_multiplier].

## Weapons the shop can offer.
@export var weapons: Array[WeaponData] = []
## Offers shown at once.
@export_range(1, 6) var offer_count: int = 4

@export_group("Tiers")
## The shop after wave N sells up to tier N + this.
@export var tier_cap_above_wave: int = 1
## Offers roll their tier from this many of the highest tiers on sale.
@export_range(1, 10) var tier_window: int = 3

@export_group("Prices (gold)")
@export var price_multiplier: float = 1.0
## Reroll cost at the first shop, before any reroll.
@export var reroll_base_cost: int = 2
## Added to the first reroll's cost for every wave after the first.
@export var reroll_cost_per_wave: int = 1
## Added to the cost after every reroll in the same shop visit.
@export var reroll_cost_increase: int = 2


## Highest tier on sale after [param wave].
func get_max_tier(wave: int) -> int:
	return clampi(wave + tier_cap_above_wave, WeaponData.MIN_TIER, WeaponData.MAX_TIER)


## Lowest tier an offer can roll after [param wave].
func get_min_tier(wave: int) -> int:
	return maxi(get_max_tier(wave) - tier_window + 1, WeaponData.MIN_TIER)


func get_price(weapon_data: WeaponData, tier: int) -> int:
	return maxi(roundi(weapon_data.base_price * tier * price_multiplier), 1)


## Cost of the next reroll after [param wave], when [param rerolls_done]
## rerolls have already been bought in this shop visit.
func get_reroll_cost(wave: int, rerolls_done: int) -> int:
	return reroll_base_cost + reroll_cost_per_wave * maxi(wave - 1, 0) + reroll_cost_increase * rerolls_done
