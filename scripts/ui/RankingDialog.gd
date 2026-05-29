extends Window
## 地图内实时排行榜。

func _init() -> void:
	title = "实时排行榜"
	size = Vector2i(620, 420)
	min_size = Vector2i(560, 360)
	transient = true
	exclusive = false
	always_on_top = true

func _ready() -> void:
	_build()
	EventBus.money_changed.connect(func(_id, _new_amount): _refresh())
	EventBus.item_acquired.connect(func(_id, _inst): _refresh())
	EventBus.history_fragments_changed.connect(func(_id, _total, _gained, _reason): _refresh())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100a06")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	_refresh()

func _refresh() -> void:
	for c in get_children():
		if c is ColorRect:
			continue
		remove_child(c)
		c.queue_free()
	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	v.add_child(_label("实时资产排行", 24, Color("#d4a843")))
	v.add_child(_label("资产 = 银两 + 藏品估值；技能可能影响估值。", 13, Color("#a89a82")))
	for i in range(GameState.ranking_data().size()):
		v.add_child(_rank_row(i + 1, GameState.ranking_data()[i]))

func _rank_row(rank: int, data: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 76)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#332414") if rank == 1 else Color("#1f1610")
	sb.border_color = data.get("color", Color("#d4a843"))
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 12
	h.offset_top = 8
	h.offset_right = -12
	h.offset_bottom = -8
	panel.add_child(h)
	h.add_child(_label("第 %d" % rank, 20, _rank_color(rank)))
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(46, 46)
	var asb := StyleBoxFlat.new()
	asb.bg_color = data.get("color", Color("#d4a843"))
	asb.set_corner_radius_all(23)
	avatar.add_theme_stylebox_override("panel", asb)
	h.add_child(avatar)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_box)
	name_box.add_child(_label("%s · Lv.%d" % [data.get("name", "?"), int(data.get("level", 1))], 17, Color("#f5e6c8")))
	name_box.add_child(_label(str(data.get("title", "")), 12, Color("#a89a82")))
	var nums := VBoxContainer.new()
	nums.custom_minimum_size = Vector2(220, 0)
	h.add_child(nums)
	nums.add_child(_label("总资产 %d 两" % int(data.get("total", 0)), 15, Color("#d4a843")))
	nums.add_child(_label("银两 %d · 藏品 %d 两 · %d 件" % [int(data.get("money", 0)), int(data.get("inv_value", 0)), int(data.get("items", 0))], 12, Color("#a89a82")))
	return panel

func _rank_color(rank: int) -> Color:
	match rank:
		1: return Color("#d4a843")
		2: return Color("#c0c0c0")
		3: return Color("#cd7f32")
		_: return Color("#7d6a4a")

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	return lbl
