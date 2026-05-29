extends Control
## 右侧纵向时间轴：12 个回合格子，当前回合高亮，4/8/12 标拍卖。

var _cells: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(46, 338)

func _ready() -> void:
	_build()
	_refresh()
	EventBus.round_started.connect(func(_n): _refresh())
	EventBus.phase_changed.connect(func(_p): _refresh())

func _build() -> void:
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 7
	col.offset_top = 7
	col.offset_right = -7
	col.offset_bottom = -7
	add_child(col)

	for i in range(GameConfig.MAX_ROUNDS):
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(30, 24)
		var lbl := Label.new()
		lbl.text = "拍" if GameConfig.AUCTION_ROUNDS.has(i + 1) else str(i + 1)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(lbl)
		col.add_child(cell)
		_cells.append(cell)

func _refresh() -> void:
	for i in range(_cells.size()):
		var cell: Panel = _cells[i]
		var round_num := i + 1
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if round_num == GameState.current_round:
			sb.bg_color = Color("#d4a843")
		elif GameConfig.AUCTION_ROUNDS.has(round_num):
			sb.bg_color = Color("#b03020").darkened(0.2)
		else:
			sb.bg_color = Color("#3a2e22")
		cell.add_theme_stylebox_override("panel", sb)
