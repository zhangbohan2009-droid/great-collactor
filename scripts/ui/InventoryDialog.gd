extends Window
## 背包：文物 / 道具 / 图鉴。

const ItemsDBRef := preload("res://scripts/data/ItemsDB.gd")

var _tabs: TabContainer
var _cn_font: SystemFont

func _init() -> void:
	title = "背包"
	size = Vector2i(820, 560)
	min_size = Vector2i(720, 500)
	transient = true
	exclusive = false
	always_on_top = true

func _ready() -> void:
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]
	_build()
	EventBus.item_acquired.connect(_on_item_changed)
	EventBus.codex_unlocked.connect(_on_codex_changed)
	EventBus.money_changed.connect(func(_id, _amount): _refresh())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100a06")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	_tabs = TabContainer.new()
	_tabs.add_theme_font_override("font", _cn_font)
	_tabs.anchor_right = 1.0
	_tabs.anchor_bottom = 1.0
	_tabs.offset_left = 14
	_tabs.offset_top = 12
	_tabs.offset_right = -14
	_tabs.offset_bottom = -14
	add_child(_tabs)
	_refresh()

func _refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_tabs.add_child(_artifact_page())
	_tabs.add_child(_tools_page())
	_tabs.add_child(_codex_page())

func _artifact_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "文物"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var p = GameState.human_player()
	if p == null:
		return scroll
	for inst in p.inventory:
		grid.add_child(_artifact_card(inst))
	if p.inventory.is_empty():
		grid.add_child(_empty_label("暂无文物，进城或拍卖可入手藏品。"))
	return scroll

func _tools_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "道具"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	var p = GameState.human_player()
	if p == null:
		return scroll
	for tool in GameConfig.TOOL_DEFS:
		var id := str(tool.get("id", ""))
		var count := int(p.tools.get(id, 0))
		v.add_child(_tool_card(str(tool.get("name", id)), count, str(tool.get("desc", ""))))
	return scroll

func _codex_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "图鉴"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	var all_items := ItemsDBRef.all_items()
	root.add_child(_label("已收录 %d / %d" % [GameState.codex_item_ids.size(), all_items.size()], 16, Color("#d4a843")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for item in all_items:
		grid.add_child(_codex_card(item))
	return scroll

func _artifact_card(inst) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(360, 128)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15")
	sb.border_color = inst.rarity_color()
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 10
	h.offset_top = 10
	h.offset_right = -10
	h.offset_bottom = -10
	panel.add_child(h)
	h.add_child(_item_icon(inst.type_icon(), inst.rarity_color()))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	v.add_child(_label("%s（%s）" % [inst.display_name(), inst.def.rarity_label()], 16, Color("#f5e6c8")))
	v.add_child(_label("国家：%s · 真伪：%s · 估值：%d 两" % [inst.def.country, "赝品" if inst.is_fake else "真品", int(inst.estimated_value)], 13, Color("#a89a82")))
	v.add_child(_label("购入：%d 两 · 第 %d 回合 · %s" % [inst.paid_price, inst.acquired_round, inst.acquired_from], 12, Color("#d4a843")))
	v.add_child(_label(inst.def.story, 12, Color("#9bd47a")))
	return panel

func _tool_card(name: String, count: int, desc: String) -> Panel:
	var panel := _base_panel(Color("#7da8d4"))
	panel.custom_minimum_size = Vector2(0, 82)
	var v := _content_box(panel)
	v.add_child(_label("%s x%d" % [name, count], 17, Color("#f5e6c8")))
	v.add_child(_label(desc, 13, Color("#a89a82")))
	return panel

func _codex_card(item) -> Panel:
	var unlocked := GameState.codex_item_ids.has(item.id)
	var panel := _base_panel(item.rarity_color() if unlocked else Color("#4d4438"))
	panel.custom_minimum_size = Vector2(220, 92)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 8
	h.offset_top = 8
	h.offset_right = -8
	h.offset_bottom = -8
	panel.add_child(h)
	h.add_child(_item_icon(item.type_icon() if unlocked else "?", item.rarity_color() if unlocked else Color("#4d4438")))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(item.display_name if unlocked else "???", 14, Color("#f5e6c8") if unlocked else Color("#7d6a4a")))
	v.add_child(_label("%s · %s" % [item.country, item.rarity_label()] if unlocked else "未收录", 12, item.rarity_color() if unlocked else Color("#7d6a4a")))
	v.add_child(_label(item.story if unlocked else "买入一次即可收录图鉴。", 11, Color("#a89a82")))
	return panel

func _item_icon(text: String, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(58, 58)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.25)
	sb.border_color = Color("#1f1610")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var lbl := _label(text, 28, Color("#f5e6c8"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(lbl)
	return p

func _base_panel(color: Color) -> Panel:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

func _content_box(panel: Panel) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 10
	v.offset_top = 8
	v.offset_right = -10
	v.offset_bottom = -8
	panel.add_child(v)
	return v

func _empty_label(text: String) -> Label:
	var lbl := _label(text, 16, Color("#a89a82"))
	lbl.custom_minimum_size = Vector2(500, 80)
	return lbl

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _on_item_changed(player_id: int, _inst) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()

func _on_codex_changed(_item_id: String) -> void:
	_refresh()
