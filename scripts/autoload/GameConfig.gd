extends Node
## 全局常量配置

const MAX_ROUNDS: int = 12
const AUCTION_ROUNDS: Array[int] = [4, 8, 12]
const TOTAL_TILES: int = 20
const PLAYER_COUNT: int = 3
const HUMAN_PLAYER_ID: int = 0

const START_MONEY: int = 300
const DICE_MIN: int = 1
const DICE_MAX: int = 6

# 稀有度 1=白 2=蓝 3=橙 4=红
const RARITY_NAMES: Array[String] = ["", "普通", "稀奇", "珍品", "神品"]
const RARITY_COLORS: Array[Color] = [
	Color("#000000"),
	Color("#bfbfbf"), # 白
	Color("#3a78a8"), # 蓝
	Color("#d4843a"), # 橙
	Color("#b03020"), # 红
]
const RARITY_PRICE_MULT: Array[float] = [0.0, 1.0, 2.0, 4.0, 8.0]

# 城市文物刷新数量
const CITY_ITEM_SLOTS: int = 4
# 单城稀有度配比（4 个槽位）
const CITY_RARITY_DISTRIBUTION: Array[int] = [1, 1, 2, 3] # 1 红 1 橙 2 蓝 ... 这里给的是“最少出现的最高稀有度门槛”，实际由 MarketSystem 控制

# 玩家颜色（HUD 棋子 头像）
const PLAYER_COLORS: Array[Color] = [
	Color("#d4a843"), # 真人 金
	Color("#3a78a8"), # AI1 蓝
	Color("#b03020"), # AI2 红
]
const PLAYER_NAMES: Array[String] = ["你", "李员外", "陆掌柜"]
const PLAYER_AVATARS: Array[String] = ["collector_gold", "ink_blue", "market_red"]
const AVATAR_COLORS: Dictionary = {
	"collector_gold": Color("#d4a843"),
	"jade_green": Color("#4a8060"),
	"ink_blue": Color("#3a78a8"),
	"market_red": Color("#b03020"),
	"merchant_blue": Color("#3a78a8"),
	"patron_red": Color("#b03020"),
}

var _avatar_block_cache: Dictionary = {}

func get_avatar_color(avatar_id: String) -> Color:
	return AVATAR_COLORS.get(avatar_id, AVATAR_COLORS["collector_gold"])

func get_avatar_texture(avatar_id: String, size: int = 64) -> Texture2D:
	var key := "%s:%d" % [avatar_id, size]
	if _avatar_block_cache.has(key):
		return _avatar_block_cache[key]
	var color: Color = get_avatar_color(avatar_id)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_avatar_block_cache[key] = tex
	return tex

const HISTORY_LEVELS: Array[Dictionary] = [
	{ "level": 1, "fragments": 0, "title": "初入行" },
	{ "level": 2, "fragments": 100, "title": "识货人" },
	{ "level": 3, "fragments": 260, "title": "小掌眼" },
	{ "level": 4, "fragments": 520, "title": "行脚藏家" },
	{ "level": 5, "fragments": 900, "title": "名铺熟客" },
	{ "level": 6, "fragments": 1400, "title": "竞买好手" },
	{ "level": 7, "fragments": 2050, "title": "一方藏家" },
	{ "level": 8, "fragments": 2850, "title": "鉴藏名士" },
	{ "level": 9, "fragments": 3800, "title": "诸国闻名" },
	{ "level": 10, "fragments": 5000, "title": "大收藏家" },
]

const DEFAULT_ATTRIBUTES: Dictionary = {
	"appraisal": 1,
	"speech": 1,
	"network": 1,
	"anti_fake": 1,
	"fortune": 1,
	"capacity": 1,
}

const ATTRIBUTE_LABELS: Dictionary = {
	"appraisal": "鉴赏",
	"speech": "口才",
	"network": "人脉",
	"anti_fake": "防伪",
	"fortune": "财运",
	"capacity": "库容",
}

const START_INVENTORY_CAPACITY: int = 8

const TOOL_DEFS: Array[Dictionary] = [
	{ "id": "fixed_dice_card", "name": "控骰卡", "category": "移动", "timing": "掷骰前", "desc": "本次掷骰指定 1-6 点。强力卡，每回合不可与其他移动卡叠加。" },
	{ "id": "reverse_card", "name": "转向卡", "category": "移动", "timing": "掷骰前", "desc": "本次掷骰后反向移动。适合避开风险格或回头抢资源。" },
	{ "id": "small_step_card", "name": "小步卡", "category": "移动", "timing": "掷骰前", "desc": "本次只掷 1-3 点，便于微调落点。" },
	{ "id": "double_step_card", "name": "疾行卡", "category": "移动", "timing": "掷骰前", "desc": "本次骰点 +2，最高不超过 6。赶路强，精准度较低。" },
	{ "id": "safe_pass_card", "name": "平安符", "category": "防御", "timing": "到达黑市", "desc": "到达黑市时自动消耗，跳过黑市事件并获得少量历史碎片。" },
	{ "id": "appraisal_coupon", "name": "鉴定券", "category": "交易", "timing": "买入时", "desc": "下次买入文物时自动抵扣 30 两手续费。" },
	{ "id": "market_peek_card", "name": "风闻卡", "category": "情报", "timing": "进城/黑市", "desc": "进入城市或黑市时自动消耗，提示本格可见货源的最高稀有度。" },
	{ "id": "auction_hint_card", "name": "拍讯卡", "category": "情报", "timing": "拍卖前", "desc": "下一次拍卖开始时自动消耗，提前获得一条拍品价值风声。" },
	{ "id": "relic_guard_card", "name": "护藏卡", "category": "防御", "timing": "预留", "desc": "未来用于保护一件藏品免受负面事件影响。当前版本先作为保值道具。" },
]

const DEFAULT_TOOLS: Dictionary = {
	"fixed_dice_card": 0,
	"reverse_card": 0,
	"small_step_card": 0,
	"double_step_card": 0,
	"safe_pass_card": 0,
	"appraisal_coupon": 0,
	"market_peek_card": 0,
	"auction_hint_card": 0,
	"relic_guard_card": 0,
}

const INITIAL_TOOL_LOADOUTS: Dictionary = {
	"collector_gold": { "fixed_dice_card": 1, "small_step_card": 1, "appraisal_coupon": 1 },
	"jade_green": { "reverse_card": 1, "appraisal_coupon": 2, "market_peek_card": 1 },
	"ink_blue": { "small_step_card": 1, "market_peek_card": 2, "safe_pass_card": 1 },
	"market_red": { "reverse_card": 2, "double_step_card": 1, "auction_hint_card": 1 },
	"ai_li": { "reverse_card": 1, "double_step_card": 1, "appraisal_coupon": 1 },
	"ai_lu": { "small_step_card": 1, "market_peek_card": 1, "auction_hint_card": 1 },
}

const MOVEMENT_TOOL_IDS: Array[String] = ["fixed_dice_card", "reverse_card", "small_step_card", "double_step_card"]

func tool_def(tool_id: String) -> Dictionary:
	for tool in TOOL_DEFS:
		if str(tool.get("id", "")) == tool_id:
			return tool
	return {}

func tool_name(tool_id: String) -> String:
	return str(tool_def(tool_id).get("name", tool_id))

const SKILL_TREE: Array[Dictionary] = [
	{ "id": "patina_eye", "track": "鉴古线", "name": "细看包浆", "cost": 1, "requires": [], "desc": "鉴定费用 -15%。" },
	{ "id": "dating_basics", "track": "鉴古线", "name": "断代入门", "cost": 1, "requires": ["patina_eye"], "desc": "鉴赏 +1，估值区间进一步收窄。" },
	{ "id": "fake_sense", "track": "鉴古线", "name": "火眼初成", "cost": 2, "requires": ["dating_basics"], "desc": "黑市购买前有 25% 概率提示疑似赝品。" },
	{ "id": "master_appraiser", "track": "鉴古线", "name": "掌眼宗师", "cost": 3, "requires": ["fake_sense"], "desc": "鉴定区间额外缩小 12%。" },
	{ "id": "familiar_face", "track": "交易线", "name": "熟客脸面", "cost": 1, "requires": [], "desc": "城市购买价 -5%。" },
	{ "id": "bargain_words", "track": "交易线", "name": "压价话术", "cost": 1, "requires": ["familiar_face"], "desc": "购买价再 -5%。" },
	{ "id": "dark_market_tip", "track": "交易线", "name": "暗盘口信", "cost": 2, "requires": ["bargain_words"], "desc": "黑市高稀有文物出现权重提升。" },
	{ "id": "auction_scheme", "track": "交易线", "name": "竞买谋略", "cost": 3, "requires": ["dark_market_tip"], "desc": "拍卖心理上限 +8%。" },
	{ "id": "pack_order", "track": "收藏线", "name": "行囊整理", "cost": 1, "requires": [], "desc": "库容 +3。" },
	{ "id": "catalog_notes", "track": "收藏线", "name": "图录校勘", "cost": 1, "requires": ["pack_order"], "desc": "首次图鉴奖励 +25%。" },
	{ "id": "mountain_search", "track": "收藏线", "name": "名山访古", "cost": 2, "requires": ["catalog_notes"], "desc": "景点历史碎片奖励 +20%。" },
	{ "id": "collector_heart", "track": "收藏线", "name": "千年藏心", "cost": 3, "requires": ["mountain_search"], "desc": "终局库存估值 +5%。" },
]

# 鉴定区间（MVP 用固定 ±30%）
const APPRAISAL_LOW: float = 0.7
const APPRAISAL_HIGH: float = 1.3

# 调试：真人也由 AI 自动操作（用于 headless smoke test）
var DEBUG_AUTOPLAY: bool = false

# 拍卖
const AUCTION_LOT_COUNT: int = 3
const AUCTION_MIN_BID_STEP: int = 20

# 文物类型到一字图标（参考 千年项目 ITEM_TYPE_ICONS）
const TYPE_ICONS: Dictionary = {
	"bronze": "鼎",
	"jade": "玉",
	"silk": "锦",
	"porcelain": "瓷",
	"painting": "山",
	"calligraphy": "書",
	"bamboo_slip": "简",
	"lacquer": "漆",
	"pottery": "陶",
	"paper": "卷",
	"weapon": "剑",
	"metal_ware": "器",
	"furniture": "椅",
	"stone": "石",
	"buddhist": "佛",
	"currency": "贝",
}

# 地图格子类型颜色
const TILE_COLORS: Dictionary = {
	"city": Color("#d4a843"),
	"black_market": Color("#5a3a78"),
	"scenic": Color("#4a8060"),
	"temple": Color("#a08868"),
}

const PHASE_NAMES: Dictionary = {
	"main_menu": "主菜单",
	"round_begin": "回合开始",
	"dice": "掷骰",
	"move": "移动",
	"event": "结算",
	"auction": "拍卖",
	"round_end": "回合结束",
	"ranking": "结算排名",
}

# 各类节点的"首次进入介绍"文案（之后由弹窗右上 ? 回看）
const TILE_INTROS: Dictionary = {
	"city": {
		"title": "城 · 古玩铺",
		"subtitle": "城邦正店，规矩在街面上立着",
		"lines": [
			"城中的古玩铺一次会摆出 4 件待沽，价标半明半暗。",
			"每件你可以先付一笔银钱「鉴定」，得到一个估值区间——区间越小，越接近真价。",
			"鉴定不等于买下；买进去的器物，先入你的私囊，回头到拍卖才见真章。",
			"提示：城价偏稳定，真假尚有商家信誉为底；越是大城，水越深。",
		],
	},
	"black_market": {
		"title": "黑市 · 暗摊",
		"subtitle": "灯下交易，自负真伪",
		"lines": [
			"黑市的器物比城里便宜不少，但赝品的概率明显更高。",
			"同样可以花钱鉴定，但区间会更宽——眼力不到家就会吃哑巴亏。",
			"赚得多、亏得也凶，是会博的人才来的地方。",
		],
	},
	"scenic": {
		"title": "景点 · 名山胜地",
		"subtitle": "走江湖也是养眼力",
		"lines": [
			"在山水之间走一遭，鉴宝心境会更稳。",
			"本回合不会发生交易，但你能借势调整一下手里的牌——",
			"在下一次进场时，估值会更准、心更不慌。",
			"（MVP 中此处暂作过场，后续将开放「眼力提升」效果）",
		],
	},
	"temple": {
		"title": "寺庙 · 古刹",
		"subtitle": "礼佛、抄经、问古",
		"lines": [
			"寺庙不收购器物，但能让你避一避江湖险风。",
			"本回合无交易，你可以稍息一会，专心备战下一次拍卖。",
			"（MVP 中此处暂作过场，后续会开放「祈愿」与「典籍」事件）",
		],
	},
}
