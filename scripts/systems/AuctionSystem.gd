extends RefCounted
class_name AuctionSystem
## 拍卖系统：3 件拍品，3 个竞拍人（含真人），轮流出价
## 简化版：每件拍品独立结算，玩家弃拍 / 出价；AI 用 AISystem 算 ceiling 后跟价

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const AISystemRef := preload("res://scripts/systems/AISystem.gd")
const ItemsDBRef := preload("res://scripts/data/ItemsDB.gd")
const ItemInstanceModel := preload("res://scripts/models/ItemInstance.gd")

## 创建一个拍卖会 session（dictionary 形态，便于 UI 直接读）
## 拍品稀有度：第 4 回合 [3,3,4]；第 8 回合 [3,4,4]；第 12 回合 [4,4,4]
const ROUND_LOT_RARITIES: Dictionary = {
	4: [3, 3, 4],
	8: [3, 4, 4],
	12: [4, 4, 4],
}

static func create_session(round_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var rarities: Array = ROUND_LOT_RARITIES.get(round_num, [3, 3, 4])
	var lots: Array = []
	var used_ids: Dictionary = {}
	for r in rarities:
		var item: Resource = null
		# 避免一场里出现重复物
		for attempt in range(8):
			var candidate = ItemsDBRef.random_item_by_rarity(r, rng)
			if candidate != null and not used_ids.has(candidate.id):
				item = candidate
				used_ids[candidate.id] = true
				break
		if item == null:
			item = ItemsDBRef.random_item_by_rarity(r, rng)
		var inst: Resource = _build_lot_instance(item, rng)
		var ceilings: Dictionary = {}
		# 给 AI 玩家算 ceiling（真人不算）
		for p in GameState.players:
			if p.is_ai:
				ceilings[p.id] = AISystemRef.make_auction_ceiling(inst.real_price, rng)
		lots.append({
			"item": item,
			"instance": inst,
			"start_bid": MarketSystemRef.auction_start_bid(inst, rng),
			"estimate": MarketSystemRef.auction_estimate(inst, rng),
			"current_bid": 0,
			"leader_id": -1,
			"ceilings": ceilings,
			"active_bidders": _all_player_ids(),
			"finished": false,
			"winner_id": -1,
			"final_price": 0,
		})
	return {
		"round_num": round_num,
		"lots": lots,
		"current_lot": 0,
		"finished": false,
	}

static func _build_lot_instance(item: Resource, rng: RandomNumberGenerator) -> Resource:
	# 拍卖场里基本都是真品
	var inst := ItemInstanceModel.new()
	inst.def = item
	inst.is_fake = false
	var mult: float = GameConfig.RARITY_PRICE_MULT[item.rarity]
	var fluct: float = rng.randf_range(0.95, 1.20)  # 拍卖场略高
	inst.real_price = max(50, int(round(float(item.base_price) * mult * fluct)))
	inst.appraised_low = max(1, int(round(inst.real_price * GameConfig.APPRAISAL_LOW)))
	inst.appraised_high = max(inst.appraised_low + 1, int(round(inst.real_price * GameConfig.APPRAISAL_HIGH)))
	inst.estimated_value = float(inst.real_price)
	return inst

static func _all_player_ids() -> Array:
	var ids: Array = []
	for p in GameState.players:
		ids.append(p.id)
	return ids

static func current_lot(session: Dictionary) -> Dictionary:
	if session.is_empty() or session.get("finished", false):
		return {}
	var idx: int = session.get("current_lot", 0)
	if idx < 0 or idx >= session["lots"].size():
		return {}
	return session["lots"][idx]

static func next_lot(session: Dictionary) -> bool:
	session["current_lot"] = int(session.get("current_lot", 0)) + 1
	if session["current_lot"] >= session["lots"].size():
		session["finished"] = true
		return false
	return true

## 给本件拍品计算下一手最低跟价（current_bid + 步长）
static func next_min_bid(lot: Dictionary) -> int:
	var current: int = int(lot.get("current_bid", 0))
	if current == 0:
		return int(lot.get("start_bid", GameConfig.AUCTION_MIN_BID_STEP))
	return current + GameConfig.AUCTION_MIN_BID_STEP

## 玩家/AI 出价。成功返回 true
static func place_bid(lot: Dictionary, bidder_id: int, amount: int) -> bool:
	if lot.get("finished", false):
		return false
	if amount < next_min_bid(lot):
		return false
	var player = GameState.get_player(bidder_id)
	if player == null or player.money < amount:
		return false
	lot["current_bid"] = amount
	lot["leader_id"] = bidder_id
	return true

## 标记某 bidder 弃拍
static func withdraw(lot: Dictionary, bidder_id: int) -> void:
	var active: Array = lot["active_bidders"]
	active.erase(bidder_id)
	lot["active_bidders"] = active

## 当只剩 1 人或全部弃拍后结算本件
## 返回 winner 信息（dict）：{ "winner_id", "final_price" }
static func try_finalize(lot: Dictionary) -> Dictionary:
	if lot.get("finished", false):
		return { "winner_id": lot.get("winner_id", -1), "final_price": lot.get("final_price", 0) }
	var active: Array = lot["active_bidders"]
	# 没人出过价且全部弃拍：流拍
	if active.size() <= 1:
		var winner_id: int = -1
		var final_price: int = 0
		if active.size() == 1:
			winner_id = active[0]
			# 唯一剩下的人就是 leader（或他刚出的价；若他没出过价就用起拍价）
			if lot.get("leader_id", -1) == winner_id:
				final_price = int(lot["current_bid"])
			else:
				# 没人出价（全是他兜底），按起拍价成交
				final_price = int(lot["start_bid"])
				lot["current_bid"] = final_price
				lot["leader_id"] = winner_id
		elif lot.get("leader_id", -1) != -1 and active.is_empty():
			# 边缘情况：leader 已经存在但所有人都被记为弃拍
			winner_id = int(lot["leader_id"])
			final_price = int(lot["current_bid"])
		lot["winner_id"] = winner_id
		lot["final_price"] = final_price
		lot["finished"] = true
	return { "winner_id": lot.get("winner_id", -1), "final_price": lot.get("final_price", 0) }
