extends RefCounted
class_name AISystem
## AI 决策：进城选品 / 拍卖出价
## 风格参考 千年项目 auction.js 的 _buildBidders / acceptBid 逻辑

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")

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
