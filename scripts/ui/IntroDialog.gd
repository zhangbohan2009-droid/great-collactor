extends Window
## 节点首次进入介绍 / ? 按钮回看：用于 城 / 黑市 / 景点 / 寺庙

func _init() -> void:
	exclusive = true
	min_size = Vector2i(520, 360)
	max_size = Vector2i(720, 560)
	transient = false

func setup(type_key: String, first_time: bool) -> void:
	var intro: Dictionary = GameConfig.TILE_INTROS.get(type_key, {})
	var title_text: String = intro.get("title", "介绍")
	var subtitle: String = intro.get("subtitle", "")
	var lines: Array = intro.get("lines", [])

	set_meta("type_key", type_key)
	title = title_text

	# 清掉旧子节点（保险）
	for child in get_children():
		child.queue_free()

	var root := PanelContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var pnl_sb := StyleBoxFlat.new()
	pnl_sb.bg_color = Color("#f5e6c8")
	pnl_sb.border_color = Color("#6b4828")
	pnl_sb.set_border_width_all(2)
	pnl_sb.set_corner_radius_all(4)
	pnl_sb.content_margin_left = 20
	pnl_sb.content_margin_right = 20
	pnl_sb.content_margin_top = 16
	pnl_sb.content_margin_bottom = 16
	root.add_theme_stylebox_override("panel", pnl_sb)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	# 标题
	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color("#2a1810"))
	vbox.add_child(title_lbl)

	# 副标题
	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.add_theme_color_override("font_color", Color("#7a5a30"))
		vbox.add_child(sub_lbl)

	# 分隔
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 正文
	for s in lines:
		var l := Label.new()
		l.text = "• " + str(s)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color("#2a1810"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(460, 0)
		vbox.add_child(l)

	# 底部按钮区
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var hint_lbl := Label.new()
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color("#7a5a30"))
	if first_time:
		hint_lbl.text = "（看完后再次进入此类节点会直接进入交易，亦可点击交易窗右上 ?  回看）"
	else:
		hint_lbl.text = "（点击「关闭」回到当前交易）"
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_row.add_child(hint_lbl)

	var ok_btn := Button.new()
	ok_btn.text = "我知道了" if first_time else "关闭"
	ok_btn.custom_minimum_size = Vector2(120, 32)
	ok_btn.pressed.connect(func(): close_requested.emit())
	btn_row.add_child(ok_btn)
