extends RefCounted
class_name MapLayout
## Real geography layout over a David Rumsey Warring States historical map.

const MapTileModel := preload("res://scripts/models/MapTile.gd")

const MAP_LNG_MIN: float = 93.0
const MAP_LNG_MAX: float = 124.0
const MAP_LAT_MIN: float = 18.0
const MAP_LAT_MAX: float = 42.5
const SPREAD_FACTOR: float = 1.10

const DEFAULT_LAYOUT: Array = [
	{ "id": "chengdu", "type": MapTileModel.Type.CITY, "name": "成都", "lat": 30.67, "lng": 104.06, "country": "蜀", "label_offset": Vector2(-76, -70), "ohm_source": "Chengdu geo anchor" },
	{ "id": "emei_temple", "type": MapTileModel.Type.TEMPLE, "name": "峨眉山寺", "lat": 29.55, "lng": 103.34, "country": "蜀", "label_offset": Vector2(34, 34), "ohm_source": "Emei Mountain geo anchor" },
	{ "id": "zhongnan_mountain", "type": MapTileModel.Type.SCENIC, "name": "终南山", "lat": 33.83, "lng": 108.95, "country": "秦", "label_offset": Vector2(-106, 24), "ohm_source": "Zhongnan Mountain geo anchor" },
	{ "id": "changan", "type": MapTileModel.Type.CITY, "name": "长安", "lat": 34.26, "lng": 108.94, "country": "秦", "label_offset": Vector2(-84, -64), "ohm_source": "Changan/Xian geo anchor" },
	{ "id": "xianyang", "type": MapTileModel.Type.CITY, "name": "咸阳", "lat": 34.33, "lng": 108.71, "country": "秦", "label_offset": Vector2(42, -24), "ohm_source": "Xianyang geo anchor" },
	{ "id": "weishui_black_market", "type": MapTileModel.Type.BLACK_MARKET, "name": "渭水 · 黑市", "lat": 34.80, "lng": 110.40, "country": "秦", "label_offset": Vector2(-56, 46), "ohm_source": "Wei River corridor geo anchor" },
	{ "id": "tongguan", "type": MapTileModel.Type.SCENIC, "name": "潼关", "lat": 34.55, "lng": 110.31, "country": "秦", "label_offset": Vector2(54, -74), "ohm_source": "Tongguan geo anchor" },
	{ "id": "luoyi", "type": MapTileModel.Type.CITY, "name": "洛邑", "lat": 34.62, "lng": 112.45, "country": "周", "label_offset": Vector2(-58, -78), "ohm_source": "Luoyi/Luoyang geo anchor" },
	{ "id": "baima_temple", "type": MapTileModel.Type.TEMPLE, "name": "白马寺", "lat": 34.66, "lng": 112.59, "country": "周", "label_offset": Vector2(-116, 8), "ohm_source": "White Horse Temple geo anchor" },
	{ "id": "xinzheng", "type": MapTileModel.Type.CITY, "name": "新郑", "lat": 34.40, "lng": 113.74, "country": "韩", "label_offset": Vector2(64, -24), "ohm_source": "Xinzheng geo anchor" },
	{ "id": "handan", "type": MapTileModel.Type.CITY, "name": "邯郸", "lat": 36.62, "lng": 114.54, "country": "赵", "label_offset": Vector2(-108, -18), "ohm_source": "Handan geo anchor" },
	{ "id": "jibei_black_market", "type": MapTileModel.Type.BLACK_MARKET, "name": "蓟北 · 黑市", "lat": 39.94, "lng": 116.40, "country": "燕", "label_offset": Vector2(62, -48), "ohm_source": "Ji/Yan geo anchor" },
	{ "id": "linzi", "type": MapTileModel.Type.CITY, "name": "临淄", "lat": 36.82, "lng": 118.31, "country": "齐", "label_offset": Vector2(58, -28), "ohm_source": "Linzi geo anchor" },
	{ "id": "linzi_market", "type": MapTileModel.Type.GAMBLING, "name": "临淄闹市", "lat": 36.62, "lng": 118.02, "country": "齐", "label_offset": Vector2(-112, 36), "ohm_source": "Linzi Qi capital market and entertainment district" },
	{ "id": "taishan", "type": MapTileModel.Type.SCENIC, "name": "泰山", "lat": 36.27, "lng": 117.10, "country": "", "label_offset": Vector2(-96, -66), "ohm_source": "Taishan geo anchor; Qi-Lu cultural boundary, no single fixed faction label" },
	{ "id": "qufu", "type": MapTileModel.Type.CITY, "name": "曲阜", "lat": 35.58, "lng": 116.99, "country": "鲁", "label_offset": Vector2(56, -70), "ohm_source": "Qufu geo anchor" },
	{ "id": "taoqiu_black_market", "type": MapTileModel.Type.BLACK_MARKET, "name": "陶丘 · 黑市", "lat": 35.25, "lng": 115.30, "country": "魏", "label_offset": Vector2(70, 36), "ohm_source": "Dingtao/Taoqiu geo anchor" },
	{ "id": "hanjiang_black_market", "type": MapTileModel.Type.BLACK_MARKET, "name": "汉江口 · 黑市", "lat": 30.50, "lng": 113.50, "country": "楚", "label_offset": Vector2(62, -52), "ohm_source": "Han River/Jianghan geo anchor" },
	{ "id": "yunmeng_marsh", "type": MapTileModel.Type.SCENIC, "name": "云梦泽", "lat": 30.27, "lng": 113.39, "country": "楚", "label_offset": Vector2(-36, 52), "ohm_source": "Yunmeng marsh geo anchor" },
	{ "id": "yingdu", "type": MapTileModel.Type.CITY, "name": "郢都", "lat": 30.34, "lng": 112.19, "country": "楚", "label_offset": Vector2(-118, -24), "ohm_source": "Yingdu/Jingzhou geo anchor" },
]

const HISTORICAL_REGIONS: Array = [
	{ "id": "qin", "name": "秦", "color": Color(0.72, 0.47, 0.18, 0.20), "points": [[104,32],[106.5,36.8],[111.5,37.4],[113.4,34.5],[110,32.8],[106,30.2]] },
	{ "id": "chu", "name": "楚", "color": Color(0.42, 0.65, 0.32, 0.18), "points": [[108.6,28.5],[112.4,32.6],[117.7,31.8],[120,29],[116,25],[111,25.6]] },
	{ "id": "qi_lu", "name": "齐鲁", "color": Color(0.26, 0.55, 0.74, 0.18), "points": [[115,34.2],[118.8,34.8],[121.5,37.6],[119,39.1],[115,37.2]] },
	{ "id": "zhao_yan", "name": "赵燕", "color": Color(0.52, 0.42, 0.78, 0.17), "points": [[112,35.4],[116.4,35.8],[121.2,40.6],[116,42],[111,38]] },
	{ "id": "wei_han", "name": "魏韩", "color": Color(0.78, 0.68, 0.30, 0.18), "points": [[110.8,33.4],[115.8,33.8],[116.2,36.2],[112,36]] },
	{ "id": "shu", "name": "蜀", "color": Color(0.32, 0.58, 0.48, 0.18), "points": [[101,28.4],[104,32.4],[107.2,31.2],[106.2,28.8],[103.5,27.2]] },
]

static func build_default_layout() -> Array:
	return DEFAULT_LAYOUT.duplicate(true)

static func historical_regions() -> Array:
	return HISTORICAL_REGIONS.duplicate(true)

static func load_base_map_meta() -> Dictionary:
	var fallback := {
		"bbox": { "minLng": MAP_LNG_MIN, "minLat": MAP_LAT_MIN, "maxLng": MAP_LNG_MAX, "maxLat": MAP_LAT_MAX },
		"width": 6144,
		"height": 4589,
		"attribution": "David Rumsey Historical Map Collection",
		"period": "Warring States period, circa 475-221 BCE",
	}
	var path := "res://assets/map/base_rumsey.json"
	if not FileAccess.file_exists(path):
		return fallback
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	if not parsed.has("bbox") or not parsed.has("width") or not parsed.has("height"):
		return fallback
	return parsed

static func load_ohm_meta() -> Dictionary:
	return load_base_map_meta()

static func _merc_y(lat_deg: float) -> float:
	var r := deg_to_rad(clampf(lat_deg, -85.0, 85.0))
	return log(tan(PI / 4.0 + r / 2.0))

static func geo_to_image_px(lng: float, lat: float, meta: Dictionary = {}) -> Vector2:
	var m := meta if not meta.is_empty() else load_base_map_meta()
	var bbox: Dictionary = m.get("bbox", {})
	var min_lng := float(bbox.get("minLng", MAP_LNG_MIN))
	var max_lng := float(bbox.get("maxLng", MAP_LNG_MAX))
	var min_lat := float(bbox.get("minLat", MAP_LAT_MIN))
	var max_lat := float(bbox.get("maxLat", MAP_LAT_MAX))
	var w := float(m.get("width", 6144))
	var h := float(m.get("height", 4589))
	var x := (lng - min_lng) / (max_lng - min_lng) * w
	var y0 := _merc_y(max_lat)
	var y1 := _merc_y(min_lat)
	var y := (_merc_y(lat) - y0) / (y1 - y0) * h
	return Vector2(x, y)

static func image_size(meta: Dictionary = {}) -> Vector2:
	var m := meta if not meta.is_empty() else load_base_map_meta()
	return Vector2(float(m.get("width", 6144)), float(m.get("height", 4589)))

static func project_geo_to_norm(lng: float, lat: float) -> Vector2:
	var nx: float = (lng - MAP_LNG_MIN) / (MAP_LNG_MAX - MAP_LNG_MIN) * 100.0
	var ny: float = (MAP_LAT_MAX - lat) / (MAP_LAT_MAX - MAP_LAT_MIN) * 100.0
	nx = 50.0 + (nx - 50.0) * SPREAD_FACTOR
	ny = 50.0 + (ny - 50.0) * SPREAD_FACTOR
	nx = clampf(nx, 5.0, 95.0)
	ny = clampf(ny, 6.0, 94.0)
	return Vector2(nx, ny)

static func norm_to_pixel(norm: Vector2, stage_size: Vector2) -> Vector2:
	return Vector2(norm.x * 0.01 * stage_size.x, norm.y * 0.01 * stage_size.y)

static func tile_pixel_position(tile_data: Dictionary, stage_size: Vector2) -> Vector2:
	var norm := project_geo_to_norm(float(tile_data.get("lng", 110.0)), float(tile_data.get("lat", 33.0)))
	return norm_to_pixel(norm, stage_size)

static func ring_positions(count: int, center: Vector2, radius_x: float, radius_y: float, start_angle_deg: float = -90.0) -> Array:
	var result: Array = []
	if count <= 0:
		return result
	var start_rad: float = deg_to_rad(start_angle_deg)
	for i in range(count):
		var t: float = float(i) / float(count)
		var a: float = start_rad + t * TAU
		result.append(Vector2(center.x + cos(a) * radius_x, center.y + sin(a) * radius_y))
	return result
