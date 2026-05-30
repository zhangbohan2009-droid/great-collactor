extends Window
## 进城交易：肉鸽式四卡，混合求售与求购。

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")

var _tile = null
var _offers: Array = []
var _cards: Array = []
var _intro_cb: Callable
var _cn_font: SystemFont
var _pending_reveal_items: Array = []
var _closing_after_reveal := false

func set_intro_callback(cb: Callable) -> void:
	_intro_cb = cb
	_ensure_help_button()

func _ensure_help_button() -> void:
	if has_node("__help_btn"):
		return
	var btn := _make_btn("?", Color("#d4a843"))
	btn.name = "__help_btn"
	btn.tooltip_text = "查看介绍"
	btn.custom_minimum_size = Vector2(32, 32)
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
	title = "进城"
	size = Vector2i(920, 660)
	min_size = Vector2i(840, 580)
	transient = true
	exclusive = true
	always_on_top = true
	unresizable = false

func setup(tile) -> void:
	_tile = tile
	title = "进城 · %s" % tile.display_name

func _ready() -> void:
	_ensure_font()
	_build()

func _ensure_font() -> void:
	if _cn_font != null:
		return
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]

func _build() -> void:
	_offers = GameFlow.get_city_offers(_tile.index)
	_apply_market_peek()
	var bg := ColorRect.new()
	bg.color = Color("#1f1610")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_label("%s · 今日行情" % _tile.display_name, 20, Color("#d4a843")))
	root.add_child(_label("四张交易卡随机刷新：求售可捡漏，求购可清库存。越贵的宝贝信息越不完整，买入后才开奖。", 13, Color("#a89a82")))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)

	for offer in _offers:
		grid.add_child(_make_offer_card(offer))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	var close_btn := _make_btn("离开", Color("#7d6a4a"))
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_request_close)
	bottom.add_child(close_btn)

func _apply_market_peek() -> void:
	var human = GameState.human_player()
	if human == null or GameState.tool_count(human.id, "market_peek_card") <= 0:
		return
	if not GameState.consume_tool(human.id, "market_peek_card"):
		return
	var best := 0
	for offer in _offers:
		var inst = offer.get("inst", offer.get("target_inst", null))
		if inst != null and inst.has_method("rarity"):
			best = max(best, int(inst.rarity()))
	var label := GameConfig.RARITY_NAMES[best] if best > 0 and best < GameConfig.RARITY_NAMES.size() else "未知"
	EventBus.toast.emit("风闻：%s 今日最高可能有「%s」级货源" % [_tile.display_name, label], "info")

func _request_close() -> void:
	if _closing_after_reveal:
		return
	if not _pending_reveal_items.is_empty():
		_closing_after_reveal = true
		_show_next_reveal_card()
		return
	emit_signal("close_requested")

func _make_offer_card(offer: Dictionary) -> Panel:
	if str(offer.get("kind", "sell")) == "buy":
		return _make_buy_request_card(offer)
	return _make_sell_card(offer)

func _make_sell_card(offer: Dictionary) -> Panel:
	var inst: Resource = offer["inst"]
	var level := int(offer.get("info_level", 1))
	var ask_price := int(offer.get("ask_price", 0))
	var card := _base_card(Color("#d4a843"))
	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 8)
	vroot.anchor_right = 1.0
	vroot.anchor_bottom = 1.0
	vroot.offset_left = 12
	vroot.offset_top = 12
	vroot.offset_right = -12
	vroot.offset_bottom = -12
	card.add_child(vroot)

	var icon_center := CenterContainer.new()
	icon_center.add_child(_relic_icon(inst, level))
	vroot.add_child(icon_center)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	vroot.add_child(body)

	body.add_child(_label("求售 · %s" % _sell_title(inst, level), 18, Color("#f5e6c8")))
	body.add_child(_label("卖家：%s · 要价：%d 两" % [str(offer.get("seller", "掌柜")), ask_price], 13, Color("#d4a843")))
	body.add_child(_label(_sell_info_text(inst, level), 13, Color("#a89a82")))
	body.add_child(_label(_risk_text(inst, level), 12, Color("#c89aff")))

	var btn_col := HBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 8)
	vroot.add_child(btn_col)
	var preview_btn := _make_btn("查看", Color("#7da8d4"))
	preview_btn.custom_minimum_size = Vector2(78, 32)
	preview_btn.pressed.connect(func(): _show_offer_preview(offer))
	btn_col.add_child(preview_btn)
	var buy_btn := _make_btn("买入", Color("#d4a843"))
	buy_btn.custom_minimum_size = Vector2(78, 32)
	buy_btn.pressed.connect(func():
		if GameFlow.human_buy_city_offer(_tile.index, offer):
			_pending_reveal_items.append(inst)
			buy_btn.disabled = true
			preview_btn.disabled = true
			body.add_child(_label("开奖：%s · 真值约 %d 两%s" % [inst.def.rarity_label(), int(inst.real_price), " · 赝品" if inst.is_fake else ""], 13, Color("#9bd47a")))
	)
	btn_col.add_child(buy_btn)
	_cards.append({ "offer": offer, "card": card })
	return card

func _make_buy_request_card(offer: Dictionary) -> Panel:
	var inst: Resource = offer["target_inst"]
	var price := int(offer.get("offer_price", 0))
	var card := _base_card(Color("#9bd47a"))
	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 8)
	vroot.anchor_right = 1.0
	vroot.anchor_bottom = 1.0
	vroot.offset_left = 12
	vroot.offset_top = 12
	vroot.offset_right = -12
	vroot.offset_bottom = -12
	card.add_child(vroot)
	var icon_center := CenterContainer.new()
	icon_center.add_child(_relic_icon(inst, 3))
	vroot.add_child(icon_center)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	vroot.add_child(body)
	body.add_child(_label("求购 · %s" % inst.display_name(), 18, Color("#f5e6c8")))
	body.add_child(_label("买主：%s · 出价：%d 两" % [str(offer.get("buyer", "客人")), price], 13, Color("#9bd47a")))
	body.add_child(_label("需求：%s · 你的库存中有匹配藏品" % str(offer.get("requirement", "不限")), 13, Color("#a89a82")))
	body.add_child(_label("购入价 %d 两 · 当前估值约 %d 两" % [inst.paid_price, int(inst.estimated_value)], 12, Color("#d4a843")))

	var btn_col := HBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 8)
	vroot.add_child(btn_col)
	var preview_btn := _make_btn("查看", Color("#7da8d4"))
	preview_btn.custom_minimum_size = Vector2(78, 32)
	preview_btn.pressed.connect(func(): _show_offer_preview(offer))
	btn_col.add_child(preview_btn)
	var sell_btn := _make_btn("卖出", Color("#9bd47a"))
	sell_btn.custom_minimum_size = Vector2(78, 32)
	sell_btn.pressed.connect(func():
		if GameFlow.human_sell_city_offer(_tile.index, offer):
			sell_btn.disabled = true
			preview_btn.disabled = true
			body.add_child(_label("已成交，库存已移出。", 13, Color("#9bd47a")))
	)
	btn_col.add_child(sell_btn)
	return card

func _show_offer_preview(offer: Dictionary) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "交易预览"
	dlg.size = Vector2i(440, 260)
	var kind := str(offer.get("kind", "sell"))
	if kind == "buy":
		var inst = offer.get("target_inst", null)
		dlg.dialog_text = "买主想收：%s\n出价：%d 两\n你的成本：%d 两\n当前估值：%d 两" % [inst.display_name(), int(offer.get("offer_price", 0)), inst.paid_price, int(inst.estimated_value)]
	else:
		var inst2 = offer.get("inst", null)
		var level := int(offer.get("info_level", 1))
		dlg.dialog_text = "%s\n要价：%d 两\n%s\n%s" % [_sell_title(inst2, level), int(offer.get("ask_price", 0)), _sell_info_text(inst2, level), _risk_text(inst2, level)]
	add_child(dlg)
	dlg.popup_centered()

func _show_next_reveal_card() -> void:
	if _pending_reveal_items.is_empty():
		emit_signal("close_requested")
		return
	var inst = _pending_reveal_items.pop_front()
	var dlg := Window.new()
	dlg.title = "新入藏品"
	dlg.size = Vector2i(560, 520)
	dlg.min_size = Vector2i(500, 460)
	dlg.transient = true
	dlg.exclusive = true
	dlg.always_on_top = true

	var bg := ColorRect.new()
	bg.color = Color("#160f0a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	dlg.add_child(bg)

	var panel := Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = -18
	panel.offset_bottom = -18
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("#2a1f15")
	psb.border_color = inst.rarity_color()
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	dlg.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	panel.add_child(root)

	var icon_center := CenterContainer.new()
	icon_center.add_child(_relic_icon(inst, 3))
	root.add_child(icon_center)
	root.add_child(_center_label(inst.display_name(), 26, Color("#f5e6c8")))
	root.add_child(_center_label("%s · %s · %s" % [inst.def.country, inst.def.rarity_label(), inst.def.type_icon()], 15, inst.rarity_color()))
	root.add_child(_center_label("购入 %d 两 · 估值约 %d 两 · %s" % [inst.paid_price, int(inst.estimated_value), "赝品" if inst.is_fake else "真品"], 14, Color("#d4a843")))
	var story := _label(inst.def.story, 14, Color("#a89a82"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(story)
	var btn := _make_btn("收下", Color("#d4a843"))
	btn.custom_minimum_size = Vector2(180, 40)
	btn.pressed.connect(func():
		dlg.queue_free()
		_show_next_reveal_card()
	)
	var c := CenterContainer.new()
	c.add_child(btn)
	root.add_child(c)
	add_child(dlg)
	dlg.popup_centered()

func _center_label(text: String, size_px: int, color: Color) -> Label:
	var lbl := _label(text, size_px, color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _sell_title(inst: Resource, level: int) -> String:
	if level >= 3:
		return "%s（%s）" % [inst.display_name(), inst.def.rarity_label()]
	if level == 2:
		return "%s · 似为%s" % [inst.display_name(), inst.def.rarity_label()]
	return "%s · 来路未明" % inst.type_icon()

func _sell_info_text(inst: Resource, level: int) -> String:
	if level >= 3:
		return "信息完整：%s国器物，稀有度 %s，估值 %d-%d 两。%s" % [inst.def.country, inst.def.rarity_label(), inst.appraised_low, inst.appraised_high, inst.def.brief]
	var range := MarketSystemRef.adjusted_appraisal_range(inst, GameState.human_player())
	if level == 2:
		return "信息半明：大致估值 %d-%d 两，细节仍需赌眼力。" % [range.x, range.y]
	return "信息不足：只知卖家开价，年代、真伪、行情都不稳。"

func _risk_text(inst: Resource, level: int) -> String:
	if level >= 3:
		return "风险：低。利润主要看议价。"
	if level == 2:
		return "风险：中。可能高估，也可能捡漏。"
	return "风险：高。贵货有开奖感，利润大但可能翻车。"

func _relic_icon(inst: Resource, level: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(90, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = inst.rarity_color().darkened(0.25) if level >= 3 else Color("#5b5650")
	sb.border_color = Color("#1f1610")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _label(inst.type_icon() if level >= 2 else "?", 34, Color("#f5e6c8"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _base_card(color: Color) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(205, 420)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)
	return card

func _make_btn(text: String, color: Color) -> Button:
	_ensure_font()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(86, 30)
	b.add_theme_font_override("font", _cn_font)
	b.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = color.darkened(0.25)
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color("#3a2e22")
	sb_disabled.border_color = Color("#4d4438")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("disabled", sb_disabled)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	b.add_theme_color_override("font_disabled_color", Color("#7d6a4a"))
	return b

func _label(text: String, size_px: int, color: Color) -> Label:
	_ensure_font()
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
