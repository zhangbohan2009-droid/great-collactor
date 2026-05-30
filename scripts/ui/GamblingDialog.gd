extends Window
## 临淄闹市赌坊：用简化六博意象做一次掷筹押注玩法。

const WAGERS: Array[int] = [20, 50, 100]

var _tile = null
var _intro_cb: Callable
var _result_lbl: Label
var _money_lbl: Label
var _buttons: Array[Button] = []

func set_intro_callback(cb: Callable) -> void:
	_intro_cb = cb
	_ensure_help_button()

func _ensure_help_button() -> void:
	if has_node("__help_btn"):
		return
	var btn := Button.new()
	btn.name = "__help_btn"
	btn.text = "?"
	btn.tooltip_text = "查看赌坊规则"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#2a1810"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f5e6c8")
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color("#fff5d6")
	btn.add_theme_stylebox_override("hover", hover)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -44
	btn.offset_top = 8
	btn.offset_right = -12
	btn.offset_bottom = 40
	btn.z_index = 100
	btn.pressed.connect(func():
		if _intro_cb.is_valid():
			_intro_cb.call()
	)
	add_child(btn)

func _init() -> void:
	title = "临淄闹市"
	size = Vector2i(620, 430)
	min_size = Vector2i(560, 360)
	transient = true
	exclusive = true
	always_on_top = true

func setup(tile) -> void:
	_tile = tile
	title = "赌坊 · %s" % tile.display_name

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#21140d")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = -18
	panel.offset_bottom = -18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.82, 0.55, 0.96)
	sb.border_color = Color("#8a4f1d")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var head := Label.new()
	head.text = "临淄闹市 · 六博赌坊"
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color("#2a1810"))
	root.add_child(head)

	var desc := Label.new()
	desc.text = "街中鼓瑟吹竽，博局开张。选一注筹码，与庄家各掷一筹，点数高者赢。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color("#6b4828"))
	root.add_child(desc)

	_money_lbl = Label.new()
	_money_lbl.add_theme_font_size_override("font_size", 16)
	_money_lbl.add_theme_color_override("font_color", Color("#2a1810"))
	root.add_child(_money_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for wager in WAGERS:
		var btn := _make_wager_button(wager)
		_buttons.append(btn)
		row.add_child(btn)

	_result_lbl = Label.new()
	_result_lbl.text = "庄家拈筹而笑：客官，押多押少，全凭胆色。"
	_result_lbl.custom_minimum_size = Vector2(0, 92)
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_lbl.add_theme_font_size_override("font_size", 17)
	_result_lbl.add_theme_color_override("font_color", Color("#2a1810"))
	root.add_child(_result_lbl)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	var close_btn := Button.new()
	close_btn.text = "收筹离场"
	close_btn.custom_minimum_size = Vector2(130, 38)
	close_btn.pressed.connect(func(): close_requested.emit())
	bottom.add_child(close_btn)

func _make_wager_button(wager: int) -> Button:
	var btn := Button.new()
	btn.text = "押 %d 两" % wager
	btn.custom_minimum_size = Vector2(120, 44)
	btn.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#6b2f18")
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color("#8a4f1d")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color("#f5e6c8"))
	btn.pressed.connect(func(w: int = wager): _roll_once(w))
	return btn

func _roll_once(wager: int) -> void:
	var player = GameState.human_player()
	if player == null:
		return
	if player.money < wager:
		_result_lbl.text = "掌柜摇头：筹码不足，莫要硬押。"
		_refresh()
		return
	var player_roll: int = GameState.rng.randi_range(1, 6)
	var house_roll: int = GameState.rng.randi_range(1, 6)
	if player_roll > house_roll:
		GameState.change_money(player.id, wager, "临淄闹市赌坊")
		_result_lbl.text = "你掷出 %d，庄家掷出 %d。你赢了 %d 两，满堂喝彩。" % [player_roll, house_roll, wager]
	elif player_roll < house_roll:
		GameState.change_money(player.id, -wager, "临淄闹市赌坊")
		_result_lbl.text = "你掷出 %d，庄家掷出 %d。输了 %d 两，筹码入了柜。" % [player_roll, house_roll, wager]
	else:
		_result_lbl.text = "你与庄家同掷 %d，平局退筹。" % player_roll
	_refresh()

func _refresh() -> void:
	var player = GameState.human_player()
	var money := 0 if player == null else int(player.money)
	_money_lbl.text = "当前银两：%d 两" % money
	for btn in _buttons:
		var wager_text := btn.text.replace("押 ", "").replace(" 两", "")
		btn.disabled = money < int(wager_text)
