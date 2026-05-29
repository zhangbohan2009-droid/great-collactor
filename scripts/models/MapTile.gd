class_name MapTile
extends Resource
## 地图格子

enum Type { CITY, BLACK_MARKET, SCENIC, TEMPLE }

@export var index: int = 0
@export var type: Type = Type.CITY
@export var display_name: String = ""
@export var lat: float = 33.0
@export var lng: float = 110.0
@export var norm_pos: Vector2 = Vector2(50, 50)   # 投影后的 0-100 归一化坐标
@export var country: String = ""
@export var label_offset: Vector2 = Vector2.ZERO
@export var ohm_source: String = ""

static func type_key(t: int) -> String:
	match t:
		Type.CITY: return "city"
		Type.BLACK_MARKET: return "black_market"
		Type.SCENIC: return "scenic"
		Type.TEMPLE: return "temple"
		_: return "city"

static func type_to_label(t: int) -> String:
	match t:
		Type.CITY: return "城"
		Type.BLACK_MARKET: return "黑"
		Type.SCENIC: return "景"
		Type.TEMPLE: return "寺"
		_: return "?"

func type_key_str() -> String:
	return type_key(type)

func type_label() -> String:
	return type_to_label(type)

func color() -> Color:
	return GameConfig.TILE_COLORS.get(type_key_str(), Color.WHITE)
