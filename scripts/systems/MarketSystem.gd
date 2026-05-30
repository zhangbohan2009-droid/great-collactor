extends RefCounted
class_name MarketSystem
## 市场系统：城市刷文物 + 价格 + 鉴定区间
## 简化版价格公式（参考 千年项目 systems/market.js）

const ItemsDBRef := preload("res://scripts/data/ItemsDB.gd")
const ItemInstanceModel := preload("res://scripts/models/ItemInstance.gd")

## 城里 4 个槽位的稀有度配比（参考策划：城里大致 1红 3橙 ... MVP 缩减）
## 这里给 4 个槽位：1 蓝 / 2 橙 / 1 红 偶尔 + 白
const CITY_RARITY_PATTERNS: Array = [
	[1, 2, 3, 4],
	[2, 2, 3, 4],
	[1, 2, 3, 3],
	[2, 3, 3, 4],
	[1, 2, 2, 3],
]

const CITY_RARITY_BY_VISIT: Array = [
	[[1, 1, 1, 2], [1, 1, 2, 2], [1, 1, 1, 1]],
	[[1, 1, 2, 2], [1, 2, 2, 3], [1, 1, 2, 3]],
	[[1, 2, 3, 3], [2, 2, 3, 3], [1, 2, 3, 4]],
	[[2, 3, 3, 4], [2, 3, 4, 4], [3, 3, 4, 4]],
]

## 黑市配比：稀有度更高，但赝品概率更大（MVP 简化为 50% 假货）
const BLACK_MARKET_PATTERNS: Array = [
	[2, 3, 4, 4],
	[1, 3, 3, 4],
	[2, 2, 3, 4],
]

const CITY_BUYER_TITLES: Array[String] = ["急用礼器的士人", "北来行商", "豪门管事", "旧藏修补客", "路过掌柜"]

const SELLER_PITCHES: Dictionary = {
	1: [
		"小玩意儿不压手，掌柜只喊 {price} 两，拿回去练眼最合适。",
		"乡间新收的日用古器，开价 {price} 两，胜在稳当。",
		"不是什么镇店宝，贵在来路清爽，{price} 两就能带走。",
	],
	2: [
		"这件有些门道，懂行的才会停步，要价 {price} 两。",
		"纹样和包浆都顺眼，掌柜说 {price} 两不二价。",
		"寻常摊上见不着这样的成色，{price} 两算给识货人的价。",
	],
	3: [
		"压箱底的好货，若不是急着周转，{price} 两绝不出手。",
		"这器物气口不俗，藏家见了要争，今日只报 {price} 两。",
		"掌柜拍着柜台说，这是能撑门面的珍品，{price} 两拿走。",
	],
	4: [
		"镇店级别的东西，错过难再遇，掌柜咬死 {price} 两。",
		"这不是普通买卖，是赌一眼定乾坤，开价 {price} 两。",
		"传闻已有豪客问过价，今日你先到，{price} 两可谈成。",
	],
}

static func _roll_real_price(item: Resource, rng: RandomNumberGenerator) -> int:
	var mult: float = GameConfig.RARITY_PRICE_MULT[item.rarity]
	var fluct: float = rng.randf_range(0.85, 1.15)
	var price: float = float(item.base_price) * mult * fluct
	return max(1, int(round(price)))

static func _make_instance(item: Resource, rng: RandomNumberGenerator, fake_chance: float = 0.0) -> Resource:
	var inst := ItemInstanceModel.new()
	inst.def = item
	inst.is_fake = rng.randf() < fake_chance
	if inst.is_fake:
		# 假货真实价值降低到 5%~25%
		var real_genuine: int = _roll_real_price(item, rng)
		inst.real_price = max(1, int(round(real_genuine * rng.randf_range(0.05, 0.25))))
		# 但展示给玩家的鉴定区间仍按真品估计
		var fake_show: int = real_genuine
		inst.appraised_low = max(1, int(round(fake_show * GameConfig.APPRAISAL_LOW)))
		inst.appraised_high = max(inst.appraised_low + 1, int(round(fake_show * GameConfig.APPRAISAL_HIGH)))
	else:
		inst.real_price = _roll_real_price(item, rng)
		inst.appraised_low = max(1, int(round(inst.real_price * GameConfig.APPRAISAL_LOW)))
		inst.appraised_high = max(inst.appraised_low + 1, int(round(inst.real_price * GameConfig.APPRAISAL_HIGH)))
	inst.estimated_value = float(inst.real_price)
	return inst

static func roll_city_offers(rng: RandomNumberGenerator, player, visit_count: int = 0, preferred_country: String = "") -> Array:
	var offers: Array = []
	var buy_slots := _city_buy_slots(rng, player)
	var sell_slots := 4 - buy_slots
	for i in range(sell_slots):
		offers.append(_roll_city_sell_offer(rng, player, visit_count, preferred_country))
	for i in range(buy_slots):
		var buy_offer := _roll_city_buy_offer(rng, player)
		if buy_offer.is_empty():
			offers.append(_roll_city_sell_offer(rng, player, visit_count, preferred_country))
		else:
			offers.append(buy_offer)
	offers.shuffle()
	return offers

static func _city_buy_slots(rng: RandomNumberGenerator, player) -> int:
	if player == null or player.inventory.is_empty():
		return 0
	var count: int = player.inventory.size()
	var chance := clampf(float(count) / 8.0, 0.25, 0.75)
	var slots := 1 if rng.randf() < chance else 0
	if count >= 5 and rng.randf() < 0.45:
		slots += 1
	return min(slots, 2)

static func _roll_city_sell_offer(rng: RandomNumberGenerator, player, visit_count: int = 0, preferred_country: String = "") -> Dictionary:
	var tier: int = clampi(visit_count, 0, CITY_RARITY_BY_VISIT.size() - 1)
	var patterns: Array = CITY_RARITY_BY_VISIT[tier]
	var pattern: Array = patterns[rng.randi() % patterns.size()]
	var rarity: int = int(pattern[rng.randi() % pattern.size()])
	if player != null and player.skills.get("dark_market_tip", false) and rng.randf() < 0.10:
		rarity = min(4, rarity + 1)
	var item := ItemsDBRef.random_item_by_rarity(rarity, rng, preferred_country)
	if item == null:
		return {}
	var fake_chance := 0.0
	if rarity == 3:
		fake_chance = 0.08
	elif rarity >= 4:
		fake_chance = 0.16
	var inst := _make_instance(item, rng, fake_chance)
	var ask := ask_price_for_player(inst, rng, player, false)
	return {
		"kind": "sell",
		"inst": inst,
		"ask_price": ask,
		"info_level": info_level_for_instance(inst, player),
		"seller": ["老铺掌柜", "行脚货郎", "士族家仆", "旧货牙人"][rng.randi() % 4],
		"pitch": _seller_pitch(inst.rarity(), ask, rng),
	}

static func _roll_city_buy_offer(rng: RandomNumberGenerator, player) -> Dictionary:
	if player == null or player.inventory.is_empty():
		return {}
	var candidates: Array = player.inventory.duplicate()
	candidates.shuffle()
	var inst: Resource = candidates[0]
	var premium: float = rng.randf_range(0.78, 1.28)
	if inst.rarity() >= 3:
		premium += rng.randf_range(0.05, 0.22)
	var offer_price: int = max(1, int(round(float(inst.real_price) * premium)))
	return {
		"kind": "buy",
		"target_inst": inst,
		"offer_price": offer_price,
		"buyer": CITY_BUYER_TITLES[rng.randi() % CITY_BUYER_TITLES.size()],
		"requirement": "%s以上 · 偏好%s" % [inst.def.rarity_label(), inst.def.type_icon()],
	}

static func info_level_for_instance(instance: Resource, player) -> int:
	var knowledge: int = 1
	if player != null:
		knowledge = int(player.attributes.get("appraisal", 1))
		if player.skills.get("dating_basics", false):
			knowledge += 1
		if player.skills.get("master_appraiser", false):
			knowledge += 2
	var difficulty: int = instance.rarity() * 2
	if instance.real_price >= 800:
		difficulty += 2
	if instance.is_fake:
		difficulty += 2
	if instance.rarity() <= 2 and instance.real_price < 180:
		return 3
	if knowledge >= difficulty:
		return 3
	if knowledge + 2 >= difficulty:
		return 2
	return 1

static func _seller_pitch(rarity: int, ask_price: int, rng: RandomNumberGenerator) -> String:
	var lines: Array = SELLER_PITCHES.get(clampi(rarity, 1, 4), SELLER_PITCHES[1])
	var text := str(lines[rng.randi() % lines.size()])
	return text.replace("{price}", str(ask_price))

## 生成城市文物列表（4 件，按一种配比）
static func roll_city_stock(rng: RandomNumberGenerator, preferred_country: String = "") -> Array:
	var pattern: Array = CITY_RARITY_PATTERNS[rng.randi() % CITY_RARITY_PATTERNS.size()]
	var stock: Array = []
	for r in pattern:
		var it := ItemsDBRef.random_item_by_rarity(r, rng, preferred_country)
		if it == null:
			continue
		var inst := _make_instance(it, rng, 0.0)
		stock.append(inst)
	return stock

## 生成黑市文物列表（4 件，有 50% 假货概率）
static func roll_black_market_stock(rng: RandomNumberGenerator, preferred_country: String = "") -> Array:
	var pattern: Array = BLACK_MARKET_PATTERNS[rng.randi() % BLACK_MARKET_PATTERNS.size()]
	var stock: Array = []
	for r in pattern:
		var it := ItemsDBRef.random_item_by_rarity(r, rng, preferred_country)
		if it == null:
			continue
		var inst := _make_instance(it, rng, 0.5)
		stock.append(inst)
	return stock

## 城里的卖价（玩家买入价）：按鉴定区间随机一个值作为售价
static func ask_price(instance: Resource, rng: RandomNumberGenerator) -> int:
	var low: int = max(1, instance.appraised_low)
	var high: int = max(low + 1, instance.appraised_high)
	return rng.randi_range(low, high)

static func ask_price_for_player(instance: Resource, rng: RandomNumberGenerator, player, is_black_market: bool = false) -> int:
	var price := ask_price(instance, rng)
	if player == null:
		return price
	var discount := float(player.attributes.get("speech", 1)) * 0.02
	if player.skills.get("familiar_face", false) and not is_black_market:
		discount += 0.05
	if player.skills.get("bargain_words", false):
		discount += 0.05
	discount = clampf(discount, 0.0, 0.28)
	return max(1, int(round(float(price) * (1.0 - discount))))

static func adjusted_appraisal_range(instance: Resource, player) -> Vector2i:
	if player == null:
		return Vector2i(instance.appraised_low, instance.appraised_high)
	var low := int(instance.appraised_low)
	var high := int(instance.appraised_high)
	var mid := float(low + high) * 0.5
	var half_width := float(high - low) * 0.5
	var shrink: float = min(0.30, float(player.attributes.get("appraisal", 1)) * 0.04)
	if player.skills.get("master_appraiser", false):
		shrink += 0.12
	half_width *= max(0.45, 1.0 - shrink)
	return Vector2i(max(1, int(round(mid - half_width))), max(2, int(round(mid + half_width))))

## 拍卖底价 / 估价（参考 千年项目 auction.js 的 startBid / estimate）
static func auction_start_bid(instance: Resource, rng: RandomNumberGenerator) -> int:
	var mid: int = int(round(float(instance.appraised_low + instance.appraised_high) / 2.0))
	return max(20, int(round(mid * rng.randf_range(0.18, 0.28))))

static func auction_estimate(instance: Resource, rng: RandomNumberGenerator) -> int:
	var mid: int = int(round(float(instance.appraised_low + instance.appraised_high) / 2.0))
	return max(30, int(round(mid * rng.randf_range(0.85, 1.20))))
