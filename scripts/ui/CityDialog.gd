extends Window
## 进城交易：肉鸽式四卡，混合求售与求购。

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const TradeResultDialog := preload("res://scripts/ui/TradeResultDialog.gd")

var _tile = null
var _offers: Array = []
var _cards: Array = []
var _intro_cb: Callable
var _cn_font: SystemFont

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
	root.add_child(_label("四张交易卡随机刷新：求售可捡漏，求购可清库存。越贵的宝贝信息越不完整，买入前更要仔细判断。", 13, Color("#a89a82")))

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
	var close_btn := _make_btn(_end_turn_button_text(), _end_turn_button_color())
	close_btn.custom_minimum_size = Vector2(230 if _will_enter_auction_after_close() else 130, 38)
	close_btn.tooltip_text = _end_turn_button_text()
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
	emit_signal("close_requested")

func _will_enter_auction_after_close() -> bool:
	return GameState.current_phase == "event" and GameState.is_auction_round(GameState.current_round)

func _end_turn_button_text() -> String:
	if _will_enter_auction_after_close():
		return "结束回合，进入拍卖会环节"
	return "结束回合"

func _end_turn_button_color() -> Color:
	if _will_enter_auction_after_close():
		return Color("#b03020")
	return Color("#7d6a4a")

func _make_offer_card(offer: Dictionary) -> Panel:
	if str(offer.get("kind", "sell")) == "buy":
		return _make_buy_request_card(offer)
	return _make_sell_card(offer)

func _make_sell_card(offer: Dictionary) -> Panel:
	var inst: Resource = offer["inst"]
	var level := int(offer.get("info_level", 1))
	var ask_price := int(offer.get("ask_price", 0))
	var card := _base_card(_visible_rarity_color(inst, level))
	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 10)
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
	body.add_theme_constant_override("separation", 8)
	vroot.add_child(body)

	body.add_child(_label(_sell_title(inst, level), 18, Color("#f5e6c8")))
	var seller := str(offer.get("seller", "掌柜"))
	var pitch := str(offer.get("pitch", _fallback_pitch(inst, ask_price)))
	var pitch_lbl := _label("%s：%s" % [seller, pitch], 13, Color("#d8c6a3"))
	pitch_lbl.custom_minimum_size = Vector2(0, 84)
	body.add_child(pitch_lbl)
	body.add_child(_price_row(ask_price))
	var rarity_hint := _rarity_hint(inst, level)
	body.add_child(_label(rarity_hint, 12, _visible_rarity_color(inst, level)))

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
		var human = GameState.human_player()
		var before_fragments := 0 if human == null else int(human.history_fragments)
		var before_level := 1 if human == null else int(human.level)
		if GameFlow.human_buy_city_offer(_tile.index, offer):
			buy_btn.disabled = true
			preview_btn.disabled = true
			human = GameState.human_player()
			var after_fragments := before_fragments if human == null else int(human.history_fragments)
			var after_level := before_level if human == null else int(human.level)
			_show_purchase_result(inst, before_fragments, before_level, after_fragments, after_level)
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
	body.add_child(_label("买主：%s" % str(offer.get("buyer", "客人")), 13, Color("#9bd47a")))
	body.add_child(_money_pair_row("出价", price, "成本", inst.paid_price))
	body.add_child(_label("需求：%s · 你的库存中有匹配藏品" % str(offer.get("requirement", "不限")), 13, Color("#a89a82")))
	body.add_child(_money_single_row("当前估值约", int(inst.estimated_value), Color("#d4a843")))

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
		var paid_price := int(inst.paid_price)
		if GameFlow.human_sell_city_offer(_tile.index, offer):
			sell_btn.disabled = true
			preview_btn.disabled = true
			body.add_child(_label("已成交，库存已移出。", 13, Color("#9bd47a")))
			_show_sale_result(inst, price, paid_price)
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

func _show_purchase_result(inst: Resource, before_fragments: int, before_level: int, after_fragments: int, after_level: int) -> void:
	var dlg := TradeResultDialog.new()
	dlg.setup_purchase(inst, before_fragments, before_level, after_fragments, after_level)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()

func _show_sale_result(inst: Resource, sale_price: int, paid_price: int) -> void:
	var dlg := TradeResultDialog.new()
	dlg.setup_sale(inst, sale_price, paid_price)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()

func _center_label(text: String, size_px: int, color: Color) -> Label:
	var lbl := _label(text, size_px, color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _sell_title(inst: Resource, level: int) -> String:
	if level >= 3:
		return "%s（%s）" % [inst.display_name(), inst.def.rarity_label()]
	return inst.display_name()

func _visible_rarity_color(inst: Resource, level: int) -> Color:
	if level >= 3:
		return inst.rarity_color()
	return Color("#6f6860")

func _rarity_hint(inst: Resource, level: int) -> String:
	if level >= 3:
		return "已识别：%s级藏品" % inst.def.rarity_label()
	return "鉴赏不足：暂看不出稀有度"

func _fallback_pitch(inst: Resource, ask_price: int) -> String:
	match inst.rarity():
		1:
			return "小件练眼，开价 %d 两，拿着不亏。" % ask_price
		2:
			return "有些门道，掌柜喊 %d 两给识货人。" % ask_price
		3:
			return "压箱底的好货，%d 两才肯松手。" % ask_price
		_:
			return "镇店级别的东西，今日开价 %d 两。" % ask_price

func _price_row(price: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.82)
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	box.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var coin := TextureRect.new()
	coin.texture = load("res://assets/ui/coin.png")
	coin.custom_minimum_size = Vector2(22, 22)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin)

	var label := _label("要价", 12, Color("#d8c6a3"))
	label.custom_minimum_size = Vector2(34, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

	var price_lbl := _label(str(price), 22, Color("#ffd166"))
	price_lbl.custom_minimum_size = Vector2(58, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
	price_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(price_lbl)

	var unit := _label("两", 12, Color("#d4a843"))
	unit.custom_minimum_size = Vector2(18, 0)
	row.add_child(unit)
	return box

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
	return "风险：高。贵货利润大，但也可能翻车。"

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

func _money_single_row(label_text: String, amount: int, color: Color = Color("#ffd166")) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.add_child(_label(label_text, 12, Color("#d8c6a3")))
	row.add_child(_coin_icon(18))
	var price_lbl := _label(str(amount), 15, color)
	price_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	price_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(price_lbl)
	row.add_child(_label("两", 12, Color("#d4a843")))
	return row

func _money_pair_row(left_label: String, left_amount: int, right_label: String, right_amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(_money_chip(left_label, left_amount, Color("#ffd166")))
	row.add_child(_money_chip(right_label, right_amount, Color("#d4a843")))
	return row

func _money_chip(label_text: String, amount: int, color: Color) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.add_child(_label(label_text, 11, Color("#d8c6a3")))
	chip.add_child(_coin_icon(16))
	var amount_lbl := _label(str(amount), 13, color)
	amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	amount_lbl.add_theme_constant_override("outline_size", 1)
	chip.add_child(amount_lbl)
	return chip

func _coin_icon(size_px: int) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = load("res://assets/ui/coin.png")
	coin.custom_minimum_size = Vector2(size_px, size_px)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return coin

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
