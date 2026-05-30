extends Control
## 地图选择：当前地图 + 占位地图，选择单人模式进入角色配置。

signal single_player_requested(map_id: String)
signal journey_mode_requested(map_id: String)
signal back_requested()

const MAP_THUMB := "res://assets/map/base_rumsey.png"

var _selected_index := 0
var _card_holder: CenterContainer
var _left_btn: Button
var _right_btn: Button

const MAPS: Array[Dictionary] = [
	{
		"id": "warring_states",
		"title": "战国七雄图",
		"desc": "以 David Rumsey 战国七雄图为底图，沿城邦线图游历、交易与拍卖。",
		"enabled": true,
	},
	{
		"id": "silk_road",
		"title": "丝路商道",
		"desc": "正在开发：后续开放西域商路、胡商与远途拍卖。",
		"enabled": false,
	},
]

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#160f0a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 52)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	root.add_child(_label("选择地图", 42, Color("#d4a843")))

	var carousel := HBoxContainer.new()
	carousel.add_theme_constant_override("separation", 20)
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(carousel)

	_left_btn = _arrow_btn("‹")
	_left_btn.pressed.connect(func(): _select_map(_selected_index - 1))
	carousel.add_child(_left_btn)

	_card_holder = CenterContainer.new()
	_card_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.add_child(_card_holder)

	_right_btn = _arrow_btn("›")
	_right_btn.pressed.connect(func(): _select_map(_selected_index + 1))
	carousel.add_child(_right_btn)
	_refresh_card()

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	var back := _btn("返回", Color("#7d6a4a"))
	back.pressed.connect(func(): back_requested.emit())
	bottom.add_child(back)

func _select_map(index: int) -> void:
	_selected_index = clampi(index, 0, MAPS.size() - 1)
	_refresh_card()

func _refresh_card() -> void:
	if _card_holder == null:
		return
	for child in _card_holder.get_children():
		_card_holder.remove_child(child)
		child.queue_free()
	var data := MAPS[_selected_index]
	_card_holder.add_child(_map_card(data))
	if _left_btn != null:
		_left_btn.disabled = _selected_index <= 0
	if _right_btn != null:
		_right_btn.disabled = _selected_index >= MAPS.size() - 1

func _map_card(data: Dictionary) -> Panel:
	var map_id := str(data.get("id", ""))
	var title := str(data.get("title", "未命名地图"))
	var desc := str(data.get("desc", ""))
	var enabled := bool(data.get("enabled", false))
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#24180f")
	sb.border_color = Color("#d4a843") if enabled else Color("#4d4438")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 16
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -16
	panel.add_child(v)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(0, 280)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture = load(MAP_THUMB) if enabled else null
	v.add_child(thumb)

	v.add_child(_label(title, 26, Color("#f5e6c8") if enabled else Color("#7d6a4a")))
	var body := _label(desc, 15, Color("#a89a82"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 12)
	v.add_child(mode_row)
	var journey := _btn("旅途模式", Color("#9bd47a"))
	journey.disabled = not enabled
	journey.tooltip_text = "轻松游玩：技能卡无限使用，开局 10000 两"
	journey.pressed.connect(func(): journey_mode_requested.emit(map_id))
	mode_row.add_child(journey)
	var single := _btn("单人模式", Color("#d4a843"))
	single.disabled = not enabled
	single.pressed.connect(func(): single_player_requested.emit(map_id))
	mode_row.add_child(single)
	var multi := _btn("多人模式（暂未开放）", Color("#7d6a4a"))
	multi.disabled = true
	v.add_child(multi)
	return panel

func _arrow_btn(text: String) -> Button:
	var b := _btn(text, Color("#d4a843"))
	b.custom_minimum_size = Vector2(72, 180)
	b.add_theme_font_size_override("font_size", 54)
	return b

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 48)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.25)
	var disabled := sb.duplicate()
	disabled.bg_color = Color("#2a2420")
	disabled.border_color = Color("#4d4438")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	b.add_theme_color_override("font_disabled_color", Color("#7d6a4a"))
	return b
