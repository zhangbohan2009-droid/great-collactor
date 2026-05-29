extends Window
## 黑市占位弹窗
## MVP 复用 CityDialog 的"刷文物 + 购买"逻辑，唯一区别：50% 假货风险（玩家鉴定不能 100% 识破）

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")

var _tile = null
var _stock: Array = []
var _cards: Array = []
var _intro_cb: Callable

func set_intro_callback(cb: Callable) -> void:
	_intro_cb = cb
	_ensure_help_button()

func _ensure_help_button() -> void:
	if has_node("__help_btn"):
		return
	var btn := Button.new()
	btn.name = "__help_btn"
	btn.text = "?"
	btn.tooltip_text = "查看介绍"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#2a1810"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f5e6c8")
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("#fff5d6")
	btn.add_theme_stylebox_override("hover", sbh)
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
	title = "黑市"
	size = Vector2i(640, 460)
	min_size = Vector2i(560, 400)
	transient = true
	exclusive = true
	always_on_top = true

func setup(tile) -> void:
	_tile = tile
	title = "黑市 · %s" % tile.display_name

func _ready() -> void:
	_stock = GameFlow.get_bm_stock(_tile.index)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1a1018")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var head := Label.new()
	head.text = "黑市 · %s（赝品居多，鉴定区间不可全信）" % _tile.display_name
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color("#c89aff"))
	v.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	for inst in _stock:
		grid.add_child(_make_card(inst))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bottom)
	var close_btn := _make_btn("离 开", Color("#7d6a4a"))
	close_btn.pressed.connect(func(): emit_signal("close_requested"))
	bottom.add_child(close_btn)

func _make_card(inst: Resource) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(260, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#28172a")
	sb.border_color = Color("#5a3a78")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.offset_left = 10
	h.offset_top = 10
	h.offset_right = -10
	h.offset_bottom = -10
	card.add_child(h)

	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(56, 56)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color("#6a5070")
	icon_sb.set_corner_radius_all(4)
	icon_panel.add_theme_stylebox_override("panel", icon_sb)
	var icon_lbl := Label.new()
	icon_lbl.text = inst.type_icon()
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	icon_lbl.anchor_right = 1.0
	icon_lbl.anchor_bottom = 1.0
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon_lbl)
	h.add_child(icon_panel)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = inst.display_name()
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	v.add_child(name_lbl)

	var info_lbl := Label.new()
	var range := MarketSystemRef.adjusted_appraisal_range(inst, GameState.human_player())
	var fake_hint := ""
	var human = GameState.human_player()
	if human != null and human.skills.get("fake_sense", false) and inst.is_fake and GameState.rng.randf() < 0.25:
		fake_hint = " · 疑似赝品"
	info_lbl.text = "估价：%d – %d 两（真伪不明%s）" % [range.x, range.y, fake_hint]
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", Color("#c89aff"))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(info_lbl)

	var ask_price := MarketSystemRef.ask_price_for_player(inst, GameState.rng, GameState.human_player(), true)
	var ask_lbl := Label.new()
	ask_lbl.text = "暗价 %d 两" % ask_price
	ask_lbl.add_theme_font_size_override("font_size", 12)
	ask_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	v.add_child(ask_lbl)

	var buy_btn := _make_btn("摸 货", Color("#9b5ee0"))
	buy_btn.custom_minimum_size = Vector2(80, 26)
	v.add_child(buy_btn)

	var data := { "inst": inst, "buy_btn": buy_btn, "info_lbl": info_lbl, "ask_price": ask_price }
	_cards.append(data)
	buy_btn.pressed.connect(_on_buy.bind(data))

	return card

func _on_buy(data: Dictionary) -> void:
	var inst: Resource = data["inst"]
	var price: int = int(data["ask_price"])
	var human = GameState.human_player()
	if human == null:
		return
	if not human.can_afford(price):
		EventBus.toast.emit("银两不足", "warn")
		return
	if human.inventory.size() >= GameState.inventory_capacity(human):
		EventBus.toast.emit("库容已满，先整理背包", "warn")
		return
	if GameFlow.human_buy_item(_tile.index, inst, price):
		var btn: Button = data["buy_btn"]
		btn.disabled = true
		btn.text = "已入手"
		var info: Label = data["info_lbl"]
		info.text = "已入手  ·  真假未明，入库估值 ≈ %d 两" % int(inst.estimated_value)

func _make_btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.5)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	var sbh := sb.duplicate()
	sbh.bg_color = color.darkened(0.3)
	var sbd := sb.duplicate()
	sbd.bg_color = Color("#3a2e22")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	return b
