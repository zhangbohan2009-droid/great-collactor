extends Control
## 终局排名屏：三人按 总资产 排名 + 称号 + 库存简列 + 返回主菜单

signal back_to_menu_requested()

const RankingSystemRef := preload("res://scripts/systems/RankingSystem.gd")

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100a06")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	var head := Label.new()
	head.text = "终  局  结  算"
	head.add_theme_font_size_override("font_size", 36)
	head.add_theme_color_override("font_color", Color("#d4a843"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)

	var sub := Label.new()
	sub.text = "（资产 = 现金 + 库存估值）"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#a89a82"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var sep := HSeparator.new()
	v.add_child(sep)

	var ranking := RankingSystemRef.compute()
	for i in range(ranking.size()):
		v.add_child(_make_rank_row(i + 1, ranking[i]))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	v.add_child(btn_row)

	var menu_btn := _make_btn("回 主 菜 单", Color("#d4a843"))
	menu_btn.pressed.connect(func(): back_to_menu_requested.emit())
	btn_row.add_child(menu_btn)

func _make_rank_row(rank: int, data: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 80)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15") if rank > 1 else Color("#3a2810")
	sb.border_color = data.get("color", Color("#d4a843"))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 16
	h.offset_top = 10
	h.offset_right = -16
	h.offset_bottom = -10
	panel.add_child(h)

	# 名次
	var rank_lbl := Label.new()
	rank_lbl.text = "第 %d 名" % rank
	rank_lbl.custom_minimum_size = Vector2(80, 0)
	rank_lbl.add_theme_font_size_override("font_size", 22)
	rank_lbl.add_theme_color_override("font_color", _rank_color(rank))
	h.add_child(rank_lbl)

	# 头像
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(48, 48)
	var asb := StyleBoxFlat.new()
	asb.bg_color = data.get("color", Color("#d4a843"))
	asb.set_corner_radius_all(24)
	avatar.add_theme_stylebox_override("panel", asb)
	h.add_child(avatar)

	# 名字 + 称号
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_box)

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	name_box.add_child(name_lbl)

	var title_lbl := Label.new()
	title_lbl.text = RankingSystemRef.title_for_rank(rank)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", _rank_color(rank))
	name_box.add_child(title_lbl)

	# 数字列
	var nums := VBoxContainer.new()
	nums.custom_minimum_size = Vector2(220, 0)
	h.add_child(nums)
	nums.add_child(_kv("总资产", "%d 两" % int(data.get("total", 0)), Color("#d4a843")))
	nums.add_child(_kv("现金", "%d 两" % int(data.get("money", 0)), Color("#f5e6c8")))
	nums.add_child(_kv("库存估值（%d 件）" % int(data.get("items", 0)), "%d 两" % int(data.get("inv_value", 0)), Color("#9bd47a")))

	return panel

func _rank_color(rank: int) -> Color:
	match rank:
		1: return Color("#d4a843")
		2: return Color("#c0c0c0")
		3: return Color("#cd7f32")
		_: return Color("#7d6a4a")

func _kv(key: String, value: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = "%s  %s" % [key, value]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var sbh := sb.duplicate()
	sbh.bg_color = color.darkened(0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	return b
