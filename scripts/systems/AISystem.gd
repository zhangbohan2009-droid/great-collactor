extends RefCounted
class_name AISystem
## AI 决策：进城选品 / 拍卖出价
## 风格参考 千年项目 auction.js 的 _buildBidders / acceptBid 逻辑

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const DiceSystemRef := preload("res://scripts/systems/DiceSystem.gd")
const MapTileModel := preload("res://scripts/models/MapTile.gd")

## 进城后从 stock 里挑一件买
## - 偏向能负担的最贵的一件（但偶尔随机偷懒，模拟 NPC 性格）
static func choose_city_pick(player, stock: Array, rng: RandomNumberGenerator):
	var affordable: Array = []
	for inst in stock:
		var ask: int = MarketSystemRef.ask_price(inst, rng)
		if player.money >= ask:
			affordable.append({ "inst": inst, "ask": ask })
	if affordable.is_empty():
		return null
	# 70% 概率拿能买得起里最贵的；30% 随机
	if rng.randf() < 0.7:
		affordable.sort_custom(func(a, b): return a["ask"] > b["ask"])
		return affordable[0]
	return affordable[rng.randi() % affordable.size()]

## 黑市：因为假货 50%，AI 更保守，只选估价中等偏下、且不超出现金 1/3 的
static func choose_black_market_pick(player, stock: Array, rng: RandomNumberGenerator):
	var budget: int = int(player.money / 3)
	var affordable: Array = []
	for inst in stock:
		var ask: int = MarketSystemRef.ask_price(inst, rng)
		if ask <= budget:
			affordable.append({ "inst": inst, "ask": ask })
	if affordable.is_empty():
		return null
	# 50% 概率跳过（怕假货）
	if rng.randf() < 0.5:
		return null
	return affordable[rng.randi() % affordable.size()]

static func choose_dice_tool(player, map_tiles: Array, rng: RandomNumberGenerator) -> Dictionary:
	if player == null or map_tiles.is_empty():
		return {}
	var default_target = _tile_after(player.position, DiceSystemRef.roll(rng), map_tiles, 1)
	if default_target != null and default_target.type == MapTileModel.Type.BLACK_MARKET and _tool_count(player, "reverse_card") > 0:
		if rng.randf() < 0.7:
			return { "id": "reverse_card", "payload": {} }
	if _tool_count(player, "fixed_dice_card") > 0 and rng.randf() < 0.35:
		var fixed_step := _best_forward_step(player, map_tiles, 6)
		if fixed_step > 0:
			return { "id": "fixed_dice_card", "payload": { "value": fixed_step } }
	if _tool_count(player, "small_step_card") > 0 and rng.randf() < 0.35:
		var short_step := _best_forward_step(player, map_tiles, 3)
		if short_step > 0:
			return { "id": "small_step_card", "payload": {} }
	if _tool_count(player, "double_step_card") > 0 and rng.randf() < 0.25:
		return { "id": "double_step_card", "payload": {} }
	return {}

static func _tool_count(player, tool_id: String) -> int:
	return int(player.tools.get(tool_id, 0))

static func _tile_after(position: int, steps: int, map_tiles: Array, direction: int):
	if map_tiles.is_empty():
		return null
	var idx := DiceSystemRef.target_index(position, steps, map_tiles.size(), direction)
	return map_tiles[idx]

static func _best_forward_step(player, map_tiles: Array, max_step: int) -> int:
	for step in range(1, max_step + 1):
		var tile = _tile_after(player.position, step, map_tiles, 1)
		if tile != null and tile.type == MapTileModel.Type.CITY and player.money >= 80:
			return step
	for step in range(1, max_step + 1):
		var tile2 = _tile_after(player.position, step, map_tiles, 1)
		if tile2 != null and tile2.type == MapTileModel.Type.SCENIC:
			return step
	return 0

## 拍卖：决定要不要跟价
## - 给每个 AI 算一个心理上限 ceiling = real_price * (0.55 ~ 1.40)
## - 当前价 + step <= ceiling 且 <= player.money 时跟
static func make_auction_ceiling(real_price: int, rng: RandomNumberGenerator) -> int:
	return int(round(real_price * rng.randf_range(0.55, 1.40)))

static func decide_auction_bid(player, current_bid: int, ceiling: int, step: int) -> int:
	var next_bid: int = current_bid + step
	if next_bid > ceiling:
		return 0
	if next_bid > player.money:
		return 0
	return next_bid
