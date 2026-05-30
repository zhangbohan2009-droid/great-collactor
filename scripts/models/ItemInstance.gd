class_name ItemInstance
extends Resource
## 一件具体的实例（玩家库存里 / 拍卖场上 / 城里待售的一件）

@export var def: Resource = null               # Item
@export var is_fake: bool = false
@export var real_price: int = 0                # 真实成交参考价
@export var appraised_low: int = 0             # 玩家看到的鉴定区间
@export var appraised_high: int = 0
@export var estimated_value: float = 0.0       # 入库后用于排名估值（≈ real_price）
@export var paid_price: int = 0
@export var acquired_round: int = 0
@export var acquired_from: String = ""
# 真伪鉴定 / 议价 临时状态（看货时使用技能后生效）
@export var appraisal_revealed: bool = false   # 已鉴定：揭示稀有度与估值
@export var fake_detected: bool = false        # 鉴定时验出赝品（估价大幅贬值）
@export var bargained: bool = false            # 本卡已议价（一卡一次）
@export var negotiated_price: int = 0          # 议价后的暗价（黑市用，0 表示按公式计算）

func display_name() -> String:
	if def == null:
		return "未知"
	return def.display_name

func rarity() -> int:
	return def.rarity if def != null else 1

func rarity_color() -> Color:
	if def == null:
		return Color.WHITE
	return def.rarity_color()

func type_icon() -> String:
	if def == null:
		return "古"
	return def.type_icon()

func to_save_dict() -> Dictionary:
	return {
		"item_id": def.id if def != null else "",
		"is_fake": is_fake,
		"real_price": real_price,
		"appraised_low": appraised_low,
		"appraised_high": appraised_high,
		"estimated_value": estimated_value,
		"paid_price": paid_price,
		"acquired_round": acquired_round,
		"acquired_from": acquired_from,
		"appraisal_revealed": appraisal_revealed,
		"fake_detected": fake_detected,
		"bargained": bargained,
		"negotiated_price": negotiated_price,
	}

func setup_from_save_dict(data: Dictionary, item_def: Resource) -> void:
	def = item_def
	is_fake = bool(data.get("is_fake", false))
	real_price = int(data.get("real_price", 0))
	appraised_low = int(data.get("appraised_low", 0))
	appraised_high = int(data.get("appraised_high", 0))
	estimated_value = float(data.get("estimated_value", 0.0))
	paid_price = int(data.get("paid_price", 0))
	acquired_round = int(data.get("acquired_round", 0))
	acquired_from = str(data.get("acquired_from", ""))
	appraisal_revealed = bool(data.get("appraisal_revealed", false))
	fake_detected = bool(data.get("fake_detected", false))
	bargained = bool(data.get("bargained", false))
	negotiated_price = int(data.get("negotiated_price", 0))
