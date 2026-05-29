class_name Item
extends Resource
## 文物定义（数据库里的一条）

@export var id: String = ""
@export var display_name: String = ""
@export var type: String = "bronze"            # bronze/jade/silk/porcelain/painting/...
@export var rarity: int = 1                    # 1 白 / 2 蓝 / 3 橙 / 4 红
@export var base_price: int = 10
@export var country: String = ""
@export var brief: String = ""
@export var story: String = ""

## 工厂函数（不写 static func from_dict，因为 class 内不能自引用 class_name）
func setup_from_dict(d: Dictionary) -> void:
	id = d.get("id", "")
	display_name = d.get("name", "")
	type = d.get("type", "bronze")
	rarity = int(d.get("rarity", 1))
	base_price = int(d.get("base_price", 10))
	country = d.get("country", "")
	brief = d.get("brief", "")
	story = d.get("story", brief)

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
