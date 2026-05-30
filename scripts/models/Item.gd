class_name Item
extends Resource
## 文物定义（数据库里的一条）

@export var id: String = ""
@export var display_name: String = ""
@export var type: String = "bronze"            # bronze/jade/silk/porcelain/painting/...
@export var rarity: int = 1                    # 1 普通 / 2 稀奇 / 3 珍品 / 4 神品
@export var base_price: int = 10
@export var country: String = ""
@export var brief: String = ""
@export var story: String = ""
@export var origin_era: String = "warring_states"
@export var era: String = "战国"
@export var origin_year: int = -475
@export var source: String = "local"

## 工厂函数（不写 static func from_dict，因为 class 内不能自引用 class_name）
func setup_from_dict(d: Dictionary) -> void:
	id = d.get("id", "")
	display_name = d.get("name", "")
	type = d.get("type", "bronze")
	rarity = _normalize_rarity(int(d.get("rarity", 1)))
	base_price = int(d.get("base_price", 10))
	country = GameConfig.REGION_LABELS.get(str(d.get("country", "")), d.get("country", ""))
	brief = d.get("brief", "")
	story = d.get("story", brief)
	origin_era = d.get("origin_era", "warring_states")
	era = d.get("era", GameConfig.ERA_NAMES.get(origin_era, "战国"))
	origin_year = int(d.get("origin_year", -475))
	source = d.get("source", "local")

func rarity_color() -> Color:
	if rarity < 1 or rarity >= GameConfig.RARITY_COLORS.size():
		return Color.WHITE
	return GameConfig.RARITY_COLORS[rarity]

func rarity_label() -> String:
	if rarity < 1 or rarity >= GameConfig.RARITY_NAMES.size():
		return "?"
	return GameConfig.RARITY_NAMES[rarity]

func type_icon() -> String:
	return GameConfig.TYPE_ICONS.get(type, "古")

func era_label() -> String:
	if era != "":
		return era
	return GameConfig.ERA_NAMES.get(origin_era, "未知时代")

func _normalize_rarity(value: int) -> int:
	if value >= 6:
		return 4
	if value >= 5:
		return 4
	if value >= 3:
		return 3
	return clampi(value, 1, 2)
