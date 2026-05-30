extends Window
## 主菜单图鉴：查看完整藏品库，支持搜索、稀有度和时代筛选。

const ItemsDBRef := preload("res://scripts/data/ItemsDB.gd")

var _cn_font: SystemFont
var _search: LineEdit
var _count_label: Label
var _grid: GridContainer
var _selected_rarity: int = 0
var _selected_era: String = ""
var _selected_map: String = ""
var _rarity_buttons: Array = []
var _era_buttons: Array = []
var _map_buttons: Array = []

func _init() -> void:
	title = "藏品图鉴"
	size = Vector2i(1120, 720)
	min_size = Vector2i(900, 620)
	transient = true
	exclusive = false
	always_on_top = true

func _ready() -> void:
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100a06")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 18
	root.offset_top = 16
	root.offset_right = -18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title_lbl := _label("藏品图鉴", 28, Color("#ffe6a8"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_lbl)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 10)
	root.add_child(search_row)

	_search = LineEdit.new()
	_search.placeholder_text = "搜索名称、地域、简介、故事"
	_search.custom_minimum_size = Vector2(420, 42)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_override("font", _cn_font)
	_search.add_theme_font_size_override("font_size", 15)
	_search.text_changed.connect(func(_text: String): _refresh())
	search_row.add_child(_search)

	_count_label = _label("", 15, Color("#d4a843"))
	_count_label.custom_minimum_size = Vector2(170, 42)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	search_row.add_child(_count_label)

	var rarity_row := HBoxContainer.new()
	rarity_row.add_theme_constant_override("separation", 8)
	root.add_child(rarity_row)
	rarity_row.add_child(_filter_caption("稀有度"))
	_build_rarity_buttons(rarity_row)

	var era_scroll := ScrollContainer.new()
	era_scroll.custom_minimum_size = Vector2(0, 46)
	era_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	era_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(era_scroll)
	var era_row := HBoxContainer.new()
	era_row.add_theme_constant_override("separation", 8)
	era_scroll.add_child(era_row)
	era_row.add_child(_filter_caption("时代"))
	_build_era_buttons(era_row)

	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	root.add_child(map_row)
	map_row.add_child(_filter_caption("出现地图"))
	_build_map_buttons(map_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

func _build_rarity_buttons(row: HBoxContainer) -> void:
	_rarity_buttons.clear()
	var all_btn := _filter_button("全部", Color("#8b7a60"), _selected_rarity == 0)
	all_btn.pressed.connect(_select_rarity.bind(0))
	row.add_child(all_btn)
	_rarity_buttons.append({ "button": all_btn, "value": 0, "color": Color("#8b7a60") })
	for i in range(GameConfig.RARITY_NAMES.size() - 1, 0, -1):
		var color: Color = GameConfig.RARITY_COLORS[i]
		var btn := _filter_button(GameConfig.RARITY_NAMES[i], color, _selected_rarity == i)
		btn.pressed.connect(_select_rarity.bind(i))
		row.add_child(btn)
		_rarity_buttons.append({ "button": btn, "value": i, "color": color })

func _build_era_buttons(row: HBoxContainer) -> void:
	_era_buttons.clear()
	var all_btn := _filter_button("全部时代", Color("#8b7a60"), _selected_era == "")
	all_btn.pressed.connect(_select_era.bind(""))
	row.add_child(all_btn)
	_era_buttons.append({ "button": all_btn, "value": "", "color": Color("#8b7a60") })
	var era_names: Array[String] = []
	for item in ItemsDBRef.all_items():
		var label: String = item.era_label()
		if label != "" and not era_names.has(label):
			era_names.append(label)
	era_names.sort()
	for era_name in era_names:
		var btn := _filter_button(era_name, Color("#7da8d4"), _selected_era == era_name)
		btn.pressed.connect(_select_era.bind(era_name))
		row.add_child(btn)
		_era_buttons.append({ "button": btn, "value": era_name, "color": Color("#7da8d4") })

func _build_map_buttons(row: HBoxContainer) -> void:
	_map_buttons.clear()
	var btn := _filter_button("战国七雄图", Color("#d4843a"), _selected_map == "warring_states_seven_heroes")
	btn.custom_minimum_size = Vector2(138, 36)
	btn.tooltip_text = "筛选当前战国七雄图中会刷出的藏品"
	btn.pressed.connect(_select_map.bind("warring_states_seven_heroes"))
	row.add_child(btn)
	_map_buttons.append({ "button": btn, "value": "warring_states_seven_heroes", "color": Color("#d4843a") })

func _refresh() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var items: Array = _items_for_selected_map()
	items.sort_custom(func(a, b) -> bool:
		if a.rarity == b.rarity:
			return a.display_name < b.display_name
		return a.rarity > b.rarity
	)

	var query := _search.text.strip_edges().to_lower()
	var rarity_value: int = _selected_rarity
	var era_value: String = _selected_era
	var shown := 0
	for item in items:
		if rarity_value > 0 and item.rarity != rarity_value:
			continue
		if era_value != "" and item.era_label() != era_value:
			continue
		if query != "" and not _item_matches_query(item, query):
			continue
		_grid.add_child(_item_card(item))
		shown += 1
	_count_label.text = "显示 %d / %d" % [shown, items.size()]
	if shown == 0:
		_grid.add_child(_empty_card())

func _items_for_selected_map() -> Array:
	if _selected_map == "warring_states_seven_heroes":
		return ItemsDBRef.gameplay_items().duplicate()
	return ItemsDBRef.all_items().duplicate()

func _item_matches_query(item, query: String) -> bool:
	var haystack := "%s %s %s %s %s %s" % [
		item.display_name,
		item.country,
		item.brief,
		item.story,
		item.era_label(),
		item.type,
	]
	return haystack.to_lower().contains(query)

func _item_card(item) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(330, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = item.rarity_color()
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 12
	h.offset_top = 12
	h.offset_right = -12
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)

	h.add_child(_item_icon(item.type_icon(), item.rarity_color()))

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	h.add_child(body)

	body.add_child(_label(item.display_name, 16, Color("#f5e6c8")))
	body.add_child(_label("%s · %s · %s" % [item.rarity_label(), item.era_label(), item.country], 12, item.rarity_color()))
	body.add_child(_label("基础价：%d 两 · 来源：%s" % [item.base_price, item.source], 11, Color("#d4a843")))
	body.add_child(_label(item.brief, 12, Color("#c9b99d")))
	var story := _label(item.story, 11, Color("#9bd47a"))
	story.custom_minimum_size = Vector2(0, 58)
	body.add_child(story)
	return panel

func _empty_card() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(330, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = Color("#4d4438")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _label("没有符合条件的藏品。", 16, Color("#a89a82"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _item_icon(text: String, color: Color) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(62, 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.32)
	sb.border_color = Color("#3b2414")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _label(text, 30, Color("#f5e6c8"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _select_rarity(value: int) -> void:
	_selected_rarity = value
	_update_filter_button_styles()
	_refresh()

func _select_era(value: String) -> void:
	_selected_era = value
	_update_filter_button_styles()
	_refresh()

func _select_map(value: String) -> void:
	_selected_map = "" if _selected_map == value else value
	_update_filter_button_styles()
	_refresh()

func _update_filter_button_styles() -> void:
	for entry in _rarity_buttons:
		var button: Button = entry["button"]
		var value: int = int(entry["value"])
		var color: Color = entry["color"]
		button.add_theme_stylebox_override("normal", _filter_style(color, value == _selected_rarity))
	for entry in _era_buttons:
		var button: Button = entry["button"]
		var value: String = str(entry["value"])
		var color: Color = entry["color"]
		button.add_theme_stylebox_override("normal", _filter_style(color, value == _selected_era))
	for entry in _map_buttons:
		var button: Button = entry["button"]
		var value: String = str(entry["value"])
		var color: Color = entry["color"]
		button.add_theme_stylebox_override("normal", _filter_style(color, value == _selected_map))

func _filter_caption(text: String) -> Label:
	var lbl := _label(text, 14, Color("#d4a843"))
	lbl.custom_minimum_size = Vector2(72, 36)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _filter_button(text: String, color: Color, selected: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(86, 36)
	btn.add_theme_font_override("font", _cn_font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_stylebox_override("normal", _filter_style(color, selected))
	btn.add_theme_stylebox_override("hover", _filter_style(color.lightened(0.15), true))
	btn.add_theme_stylebox_override("pressed", _filter_style(color.darkened(0.15), true))
	btn.add_theme_color_override("font_color", Color("#f5e6c8") if selected else Color("#c9b99d"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	return btn

func _filter_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.38) if selected else Color("#1f1610")
	style.border_color = color if selected else color.darkened(0.28)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
