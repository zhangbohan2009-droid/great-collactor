extends Node
## 全局常量配置

const MAX_ROUNDS: int = 20
const AUCTION_ROUNDS: Array[int] = [8, 14, 20]
const TOTAL_TILES: int = 20
const PLAYER_COUNT: int = 3
const HUMAN_PLAYER_ID: int = 0

const START_MONEY: int = 300
const JOURNEY_START_MONEY: int = 10000
const JOURNEY_TOOL_COUNT: int = 999
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

const ERA_NAMES: Dictionary = {
	"ancient": "远古",
	"spring_autumn": "春秋",
	"warring_states": "战国",
	"qin": "秦",
	"western_han": "西汉",
	"xin_eastern_han": "新莽 · 东汉",
	"three_kingdoms": "三国",
	"jin": "两晋",
	"northern_southern": "南北朝",
	"sui_tang": "隋唐",
	"five_dynasties": "五代十国",
	"song": "两宋",
	"yuan": "元",
	"ming": "明",
	"qing": "清",
	"republic": "民国",
	"modern": "现代",
}

const REGION_LABELS: Dictionary = {
	"zhou": "周",
	"qi": "齐",
	"chu": "楚",
	"qin": "秦",
	"yan": "燕",
	"han": "韩",
	"zhao": "赵",
	"wei": "魏",
	"yue": "越",
	"wu": "吴",
	"lu": "鲁",
	"song": "宋",
	"zheng": "郑",
	"shu": "蜀",
	"zeng": "曾",
	"zhongshan": "中山",
	"xianyang": "秦",
	"changan": "汉",
	"luoyang": "周",
	"jiankang": "建康",
	"kaifeng": "汴梁",
	"linan": "临安",
	"jingdezhen": "景德镇",
	"beijing": "北京",
	"nanjing": "南京",
	"shanghai": "上海",
}

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
const PLAYER_AVATAR_KEY_ART := "res://assets/art/key/player_avatars_key_art.png"
const KEY_ART_AVATAR_COLUMNS: Dictionary = {
	"collector_gold": 0,
	"jade_green": 0,
	"ink_blue": 1,
	"merchant_blue": 1,
	"market_red": 2,
	"patron_red": 2,
}

var _avatar_block_cache: Dictionary = {}
var _avatar_portrait_cache: Dictionary = {}

func get_avatar_color(avatar_id: String) -> Color:
	return AVATAR_COLORS.get(avatar_id, AVATAR_COLORS["collector_gold"])

func get_avatar_texture(avatar_id: String, size: int = 64) -> Texture2D:
	var key := "%s:%d" % [avatar_id, size]
	if _avatar_block_cache.has(key):
		return _avatar_block_cache[key]
	if KEY_ART_AVATAR_COLUMNS.has(avatar_id):
		var tex := _make_key_art_avatar_texture(avatar_id, size)
		if tex != null:
			_avatar_block_cache[key] = tex
			return tex
	var color: Color = get_avatar_color(avatar_id)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_avatar_block_cache[key] = tex
	return tex

func _make_key_art_avatar_texture(avatar_id: String, size: int) -> Texture2D:
	var src := Image.new()
	if src.load(PLAYER_AVATAR_KEY_ART) != OK:
		return null
	var column: int = int(KEY_ART_AVATAR_COLUMNS.get(avatar_id, 0))
	var third_w: int = int(src.get_width() / 3)
	var crop_size: int = min(third_w, src.get_height())
	var src_x: int = column * third_w + int((third_w - crop_size) * 0.5)
	var src_y: int = 0
	var cropped := Image.create(crop_size, crop_size, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(src, Rect2i(src_x, src_y, crop_size, crop_size), Vector2i.ZERO)
	cropped.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cropped)

func get_avatar_portrait_texture(avatar_id: String, size: Vector2i = Vector2i(150, 190)) -> Texture2D:
	var key := "%s:%dx%d" % [avatar_id, size.x, size.y]
	if _avatar_portrait_cache.has(key):
		return _avatar_portrait_cache[key]
	var tex := _make_key_art_portrait_texture(avatar_id, size)
	if tex == null:
		tex = get_avatar_texture(avatar_id, min(size.x, size.y))
	_avatar_portrait_cache[key] = tex
	return tex

func _make_key_art_portrait_texture(avatar_id: String, size: Vector2i) -> Texture2D:
	var src := Image.new()
	if src.load(PLAYER_AVATAR_KEY_ART) != OK:
		return null
	var column: int = int(KEY_ART_AVATAR_COLUMNS.get(avatar_id, 0))
	var third_w: int = int(src.get_width() / 3)
	var src_x: int = column * third_w
	var crop := Image.create(third_w, src.get_height(), false, Image.FORMAT_RGBA8)
	crop.blit_rect(src, Rect2i(src_x, 0, third_w, src.get_height()), Vector2i.ZERO)
	crop.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(crop)

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
	{ "id": "safe_pass_card", "name": "平安符", "category": "防御", "timing": "预留", "desc": "黑市属于增益交易地块，不会被平安符跳过。当前版本平安符先作为保值护身道具保留。" },
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

# 技能线对应关系：鉴古线 = 真伪鉴定，交易线 = 议价。技能等级 = 该线已点亮节点数。
const APPRAISAL_TRACK: String = "鉴古线"
const BARGAIN_TRACK: String = "交易线"
# 开局自动赠送的两条线根节点
const STARTING_SKILL_IDS: Array[String] = ["patina_eye", "familiar_face"]

# 议价每级降/抬价幅度（按技能等级线性累加）
const BARGAIN_RATE_PER_LEVEL: float = 0.04
# 鉴定检出赝品的基础概率 + 每级加成
const APPRAISAL_FAKE_BASE: float = 0.40
const APPRAISAL_FAKE_PER_LEVEL: float = 0.15
# 验出赝品后，展示估价直接贬值到真实价值（已是真品价的 5%~25%），再额外打折表示“砸手里”
const FAKE_REVEAL_VALUE_MULT: float = 1.0

# 鉴定文字互动台词
const APPRAISAL_FLAVOR: Dictionary = {
	"genuine": [
		"你借着光细看包浆与铸口，纹路自然、锈色入骨——是开门的真东西。",
		"上手掂了掂分量，又看了看底款，越看越顺眼，确是真品。",
		"凑近闻了闻土沁味，再以指腹摩挲断面，心里有了底：真。",
	],
	"fake": [
		"你眯眼一看，包浆浮在表面，锈色一抹就掉——这是新仿的赝品！",
		"底款笔意僵硬，铸口过于齐整，分量也不对——赝品无疑。",
		"灯下细察，沁色是后做的，火气未褪，分明是一件赝品！",
	],
}

# 议价文字互动台词（buy=压价；sell=抬价）
const BARGAIN_FLAVOR: Dictionary = {
	"buy": [
		"“掌柜的，这价我可吃不消，少算些才好长久做买卖。”对方沉吟片刻，松了口。",
		"你不动声色指出几处小瑕，对方脸上挂不住，价钱应声而落。",
		"“老主顾了，给个实在价。”一番周旋，终于压下来几分。",
	],
	"sell": [
		"你将这件器物的来路与品相娓娓道来，买主眼睛一亮，加了价。",
		"“这样的成色，过了这村可没这店。”买主权衡再三，添了银钱。",
		"你不急着出手，反让买主先开口，几轮拉扯下来，价码抬高了。",
	],
}

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
	"gambling": Color("#9a4f24"),
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
	"gambling": {
		"title": "赌坊 · 六博局",
		"subtitle": "临淄闹市的娱乐摊，赢亏都见真章",
		"lines": [
			"赌坊玩法：选择 20 / 50 / 100 两作筹码，与庄家各掷一筹。",
			"点数高者赢；你赢则获得等额银两，庄家赢则扣除筹码，平局退回。",
			"这是高波动补钱点，不产出文物；钱少时请谨慎下注。",
			"之后再进赌坊会直接进入玩法窗口，右上角 ? 可以随时回看规则。",
		],
	},
}

var LOCATION_INTROS: Dictionary = {}

func _ensure_location_intros() -> void:
	if not LOCATION_INTROS.is_empty():
		return
	LOCATION_INTROS = {
	"chengdu": _city_intro("成都", "蜀地", "巴蜀商路的起点，漆器、玉器与西南旧藏在此汇流。"),
	"changan": _city_intro("长安", "秦", "关中腹地的重镇，兵器与青铜礼器消息最密。"),
	"xianyang": _city_intro("咸阳", "秦", "秦国中枢近侧，制度严整，货源价格稳定但竞争激烈。"),
	"luoyi": _city_intro("洛邑", "周", "周室旧都，礼器、典籍与旧贵族藏品传闻最多。"),
	"xinzheng": _city_intro("新郑", "韩", "韩地工匠与市井交易活跃，常能遇到小而精的器物。"),
	"handan": _city_intro("邯郸", "赵", "赵地重城，边地军器与贵族旧藏都可能流入坊市。"),
	"linzi": _city_intro("临淄", "齐", "齐国富庶，商贾云集，高价货与赝品都会更多。"),
	"linzi_market": _linzi_market_intro(),
	"qufu": _city_intro("曲阜", "鲁", "礼乐旧地，竹简、礼器与文教相关藏品更容易出现。"),
	"yingdu": _city_intro("郢都", "楚", "楚地都邑，漆器、丝织与南方风格器物更具特色。"),
	"weishui_black_market": _black_market_intro("渭水黑市", "秦地水陆暗线，价低但鉴定信息更不可靠。"),
	"jibei_black_market": _black_market_intro("蓟北黑市", "燕赵边地的暗摊，军器与远来旧货混杂。"),
	"taoqiu_black_market": _black_market_intro("陶丘黑市", "魏地商路节点，转手快，赝品也快。"),
	"hanjiang_black_market": _black_market_intro("汉江口黑市", "楚地水路暗市，稀有货出现率高，风险也高。"),
	"zhongnan_mountain": _scenic_intro("终南山", "秦岭北麓", "秦地山势深远，隐士、方术与关中旧闻都在山路间流传。"),
	"tongguan": _scenic_intro("潼关", "关中门户", "扼守东西通道的险关，商队、军旅与流散器物常在此交会。"),
	"taishan": _scenic_intro("泰山", "齐鲁形胜", "齐鲁礼制想象中的高山，登临可见诸国气象与礼器秩序。"),
	"yunmeng_marsh": _scenic_intro("云梦泽", "楚地泽国", "江汉之间的水泽地带，楚风器物与民间传闻常在此汇集。"),
	"emei_temple": _temple_intro("峨眉山寺", "蜀地佛缘", "山寺临云，适合沉心整理见闻，后续可承接拜佛累计与佛缘事件。"),
	"baima_temple": _temple_intro("白马寺", "洛邑古刹", "中原佛寺意象的核心地点，适合展开典籍、祈愿与古刹藏物事件。"),
	}

func location_intro_for_tile(tile) -> Dictionary:
	_ensure_location_intros()
	if tile != null:
		var intro: Dictionary = LOCATION_INTROS.get(str(tile.id), {})
		if not intro.is_empty():
			return intro
		var fallback: Dictionary = TILE_INTROS.get(tile.type_key_str(), {}).duplicate(true)
		fallback["title"] = str(tile.display_name)
		fallback["category"] = tile.type_key_str()
		fallback["region"] = str(tile.country)
		return fallback
	return {}

func _city_intro(place_name: String, region_name: String, hook: String) -> Dictionary:
	return {
		"title": place_name,
		"category": "city",
		"subtitle": "%s · 城市坊市" % region_name,
		"region": region_name,
		"lines": [
			hook,
			"点击城市标记可查看本地背景；真正抵达城市时，会进入古玩铺交易。",
			"城市交易相对规整，价格较黑市稳定，但高价值货物仍需要鉴定判断。",
			"重复到访会提高当地货源质量，适合围绕路线规划收购节奏。",
		],
	}

func _black_market_intro(place_name: String, hook: String) -> Dictionary:
	return {
		"title": place_name,
		"category": "black_market",
		"subtitle": "黑市规则 · 高收益高风险",
		"region": "暗市",
		"lines": [
			hook,
			"黑市货物整体更便宜，也更容易刷出高稀有度物件。",
			"赝品概率明显更高，鉴定区间也会更宽，眼力不足时容易亏损。",
			"黑市属于增益交易地块，平安符不会跳过黑市；风闻卡可提前提示可见货源的最高稀有度。",
		],
	}

func _linzi_market_intro() -> Dictionary:
	return {
		"title": "临淄闹市",
		"category": "gambling",
		"subtitle": "齐都商业街 · 娱乐街 · 都市景观",
		"region": "齐 · 今山东淄博临淄一带",
		"image": "res://assets/ui/location_intros/linzi/liubo_board.jpg",
		"image_credit": {
			"source": "https://commons.wikimedia.org/wiki/File:Six_sticks_(liubo)_game_board_and_two_players,_China,_Henan_province,_Eastern_Han_dynasty,_1st-2nd_century_AD,_earthenware_with_calcified_green_lead_glaze_-_Portland_Art_Museum_-_Portland,_Oregon_-_DSC08590.jpg",
			"license": "Public Domain / CC0",
			"author": "Daderot",
		},
		"lines": [
			"临淄是战国齐国都城，今山东淄博临淄一带，是当时东方重要的政治、经济与文化中心。",
			"《史记·苏秦列传》称「临淄甚富而实」，民众吹竽、鼓瑟、弹琴、击筑，也斗鸡、走狗、六博、蹴鞠。",
			"史书以「车毂击，人肩摩，连衽成帷，举袂成幕，挥汗成雨」形容其街市拥挤与繁华。",
			"游戏中把这里做成闹市赌坊：它不是古玩铺，而是用六博意象表现齐都娱乐商业气氛。",
			"参考资料：山东省民政厅《山东古镇古村》齐都镇；《史记·苏秦列传》；Wikimedia Commons Liubo 公共领域图片。",
		],
	}

func _scenic_intro(place_name: String, region_name: String, hook: String) -> Dictionary:
	return {
		"title": place_name,
		"category": "scenic",
		"subtitle": "%s · 景区游历" % region_name,
		"region": region_name,
		"image": "res://assets/ui/location_intros/scenic/mountain_background.png",
		"image_credit": {
			"source": "https://lpc.opengameart.org/content/bevouliin-free-mountain-game-background",
			"license": "CC0 / Public Domain",
			"author": "Bevouliin",
		},
		"lines": [
			hook,
			"景区节点当前提供历史碎片奖励，并预留 NPC 相遇、隐藏成就和地点图鉴解锁。",
			"后续可按地点扩展独立事件，例如山路偶遇、碑刻拓片、地方传说与特殊技能线索。",
		],
	}

func _temple_intro(place_name: String, region_name: String, hook: String) -> Dictionary:
	return {
		"title": place_name,
		"category": "temple",
		"subtitle": "%s · 宗教地点" % region_name,
		"region": region_name,
		"image": "res://assets/ui/location_intros/temple/temple_cc0.png",
		"image_credit": {
			"source": "https://opengameart.org/content/primative-temple-like-structure",
			"license": "CC0 / Public Domain",
			"author": "OpenGameArt contributor",
		},
		"lines": [
			hook,
			"宗教地点当前提供历史碎片奖励，并预留拜佛累计、祈愿、典籍事件与红色技能触发。",
			"与景区不同，寺庙数据结构保留佛缘/宗教事件扩展入口，后续可记录参拜次数和地点专属奖励。",
		],
	}
