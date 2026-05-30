extends Window
## 进城交易：肉鸽式四卡，混合求售与求购。

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const TradeResultDialog := preload("res://scripts/ui/TradeResultDialog.gd")
const CoinIcon := preload("res://scripts/ui/CoinIcon.gd")

var _tile = null
var _offers: Array = []
var _cards: Array = []
var _intro_cb: Callable
var _cn_font: SystemFont
var _grid: GridContainer
var _trade_buttons: Array = []

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
	size = Vector2i(1360, 900)
	min_size = Vector2i(1160, 780)
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

	var visits: int = GameState.human_city_visit_count(_tile.index)
	var visit_tag: String = "首次到访" if visits == 0 else "到访 +%d" % visits
	root.add_child(_label("%s · 今日行情（%s）" % [_tile.display_name, visit_tag], 20, Color("#d4a843")))
	root.add_child(_label("四张交易卡随机刷新：求售可捡漏，求购可清库存。随到访次数累积，城中出现的货色稀有度会逐步提升；初到此城多为寻常白蓝货。", 13, Color("#a89a82")))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	_grid = grid

	for offer in _offers:
		grid.add_child(_make_offer_card(offer))
	if not GameState.can_trade_this_turn():
		_lock_trading()

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
	var level := _effective_level(inst, int(offer.get("info_level", 1)))
	var ask_price := int(offer.get("ask_price", 0))
	var card := _base_card(_visible_rarity_color(inst, level))
	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 8)
	vroot.anchor_right = 1.0
	vroot.anchor_bottom = 1.0
	vroot.offset_left = 12
	vroot.offset_top = 12
	vroot.offset_right = -12
	vroot.offset_bottom = -12
	card.add_child(vroot)

	vroot.add_child(_card_top_row(offer, card))

	var icon_center := CenterContainer.new()
	icon_center.add_child(_relic_icon(inst, level))
	vroot.add_child(icon_center)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	vroot.add_child(body)

	body.add_child(_label(_sell_title(inst, level), 18, Color("#f5e6c8")))
	var seller := str(offer.get("seller", "掌柜"))
	var pitch := str(offer.get("pitch", _fallback_pitch(inst, ask_price)))
	var pitch_lbl := _label("%s：%s" % [seller, pitch], 13, Color("#d8c6a3"))
	pitch_lbl.custom_minimum_size = Vector2(0, 64)
	body.add_child(pitch_lbl)
	body.add_child(_price_row(ask_price))
	body.add_child(_label(_rarity_hint(inst, level), 12, _visible_rarity_color(inst, level)))

	var skill_row := _skill_button_row(offer, card, "sell")
	if skill_row != null:
		vroot.add_child(skill_row)

	var btn_col := HBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 8)
	vroot.add_child(btn_col)
	var preview_btn := _make_btn("查看", Color("#7da8d4"))
	preview_btn.custom_minimum_size = Vector2(78, 30)
	preview_btn.pressed.connect(func(): _show_offer_preview(offer))
	btn_col.add_child(preview_btn)
	var buy_btn := _make_btn("买入", Color("#d4a843"))
	buy_btn.custom_minimum_size = Vector2(78, 30)
	buy_btn.pressed.connect(func():
		var human = GameState.human_player()
		var before_fragments := 0 if human == null else int(human.history_fragments)
		var before_level := 1 if human == null else int(human.level)
		if GameFlow.human_buy_city_offer(_tile.index, offer):
			_lock_trading()
			human = GameState.human_player()
			var after_fragments := before_fragments if human == null else int(human.history_fragments)
			var after_level := before_level if human == null else int(human.level)
			_show_purchase_result(inst, before_fragments, before_level, after_fragments, after_level)
	)
	btn_col.add_child(buy_btn)
	_trade_buttons.append(buy_btn)
	_cards.append({ "offer": offer, "card": card })
	return card

func _make_buy_request_card(offer: Dictionary) -> Panel:
	var inst: Resource = offer["target_inst"]
	var price := int(offer.get("offer_price", 0))
	var card := _base_card(Color("#9bd47a"))
	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 6)
	vroot.anchor_right = 1.0
	vroot.anchor_bottom = 1.0
	vroot.offset_left = 12
	vroot.offset_top = 12
	vroot.offset_right = -12
	vroot.offset_bottom = -12
	card.add_child(vroot)

	vroot.add_child(_card_top_row(offer, card))

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

	var skill_row := _skill_button_row(offer, card, "buy")
	if skill_row != null:
		vroot.add_child(skill_row)

	var btn_col := HBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 8)
	vroot.add_child(btn_col)
	var preview_btn := _make_btn("查看", Color("#7da8d4"))
	preview_btn.custom_minimum_size = Vector2(78, 30)
	preview_btn.pressed.connect(func(): _show_offer_preview(offer))
	btn_col.add_child(preview_btn)
	var sell_btn := _make_btn("卖出", Color("#9bd47a"))
	sell_btn.custom_minimum_size = Vector2(78, 30)
	sell_btn.pressed.connect(func():
		var paid_price := int(inst.paid_price)
		if GameFlow.human_sell_city_offer(_tile.index, offer):
			_lock_trading()
			_show_sale_result(inst, price, paid_price)
	)
	btn_col.add_child(sell_btn)
	_trade_buttons.append(sell_btn)
	_cards.append({ "offer": offer, "card": card })
	return card

func _card_top_row(offer: Dictionary, card: Panel) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var refreshed: bool = bool(offer.get("refreshed", false))
	var refresh := _make_btn("刷新", Color("#7da8d4") if not refreshed else Color("#6b6258"))
	refresh.custom_minimum_size = Vector2(56, 24)
	refresh.add_theme_font_size_override("font_size", 12)
	if refreshed:
		refresh.disabled = true
		refresh.tooltip_text = "本卡已刷新过，无法再次刷新"
	else:
		refresh.tooltip_text = "换一件（从卡池重抽，每张卡限一次）"
		refresh.pressed.connect(func(): _refresh_card(offer, card))
	row.add_child(refresh)
	return row

func _refresh_card(offer: Dictionary, card: Panel) -> void:
	var new_offer: Dictionary = GameFlow.refresh_city_offer(_tile.index, offer)
	if new_offer.is_empty():
		EventBus.toast.emit("暂时换不出新货", "warn")
		return
	new_offer["refreshed"] = true
	_replace_offer_card(card, new_offer)

func _replace_offer_card(old_card: Panel, new_offer: Dictionary) -> void:
	if not is_instance_valid(old_card) or _grid == null:
		return
	var idx := old_card.get_index()
	var new_card := _make_offer_card(new_offer)
	_grid.add_child(new_card)
	_grid.move_child(new_card, idx)
	old_card.queue_free()
	if not GameState.can_trade_this_turn():
		_lock_trading()

func _lock_trading() -> void:
	for b in _trade_buttons:
		if is_instance_valid(b):
			b.disabled = true

func _skill_button_row(offer: Dictionary, card: Panel, kind: String) -> HBoxContainer:
	var inst: Resource = offer.get("inst", offer.get("target_inst", null))
	if inst == null:
		return null
	var buttons: Array = []
	# 鉴定：仅在“买货”卡（求售/黑市）且尚未鉴定时可能出现
	if kind != "buy" and not inst.appraisal_revealed and GameState.rng.randf() < 0.5:
		buttons.append(_appraisal_button(offer, card, inst))
	# 议价：本卡未议价时可能出现
	if not inst.bargained and GameState.rng.randf() < 0.5:
		buttons.append(_bargain_button(offer, card, inst, kind))
	if buttons.is_empty():
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for b in buttons:
		row.add_child(b)
	return row

func _appraisal_button(offer: Dictionary, card: Panel, inst: Resource) -> Button:
	var lv: int = GameState.appraisal_skill_level(GameState.human_player())
	var b := _make_btn("鉴定真伪", Color("#7da8d4"))
	b.custom_minimum_size = Vector2(98, 28)
	if lv <= 0:
		b.disabled = true
		b.tooltip_text = "需要解锁『真伪鉴定』技能"
	else:
		b.tooltip_text = "动用眼力鉴定真伪并收窄估值（Lv.%d）" % lv
		b.pressed.connect(func(): _use_appraisal(offer, card, inst, lv))
	return b

func _bargain_button(offer: Dictionary, card: Panel, inst: Resource, kind: String) -> Button:
	var lv: int = GameState.bargain_skill_level(GameState.human_player())
	var is_sell_to_npc := kind == "buy"
	var label := "议价抬价" if is_sell_to_npc else "议价压价"
	var b := _make_btn(label, Color("#9bd47a"))
	b.custom_minimum_size = Vector2(98, 28)
	if lv <= 0:
		b.disabled = true
		b.tooltip_text = "需要解锁『议价』技能"
	else:
		var pct: int = int(round(float(lv) * GameConfig.BARGAIN_RATE_PER_LEVEL * 100.0))
		b.tooltip_text = "%s（Lv.%d，约 %d%%）" % [label, lv, pct]
		b.pressed.connect(func(): _use_bargain(offer, card, inst, kind, lv))
	return b

func _use_appraisal(offer: Dictionary, card: Panel, inst: Resource, lv: int) -> void:
	inst.appraisal_revealed = true
	var chance: float = GameConfig.APPRAISAL_FAKE_BASE + float(lv) * GameConfig.APPRAISAL_FAKE_PER_LEVEL
	var detected: bool = inst.is_fake and GameState.rng.randf() < chance
	inst.fake_detected = detected
	if detected:
		inst.estimated_value = float(inst.real_price)
		var lines: Array = GameConfig.APPRAISAL_FLAVOR["fake"]
		_show_flavor_popup("鉴定 · 赝品！", "%s\n\n此物现形为赝品，估价大幅缩水，切莫接手。" % str(lines[GameState.rng.randi() % lines.size()]))
	else:
		var lines2: Array = GameConfig.APPRAISAL_FLAVOR["genuine"]
		_show_flavor_popup("鉴定 · 真品", str(lines2[GameState.rng.randi() % lines2.size()]))
	_replace_offer_card(card, offer)

func _use_bargain(offer: Dictionary, card: Panel, inst: Resource, kind: String, lv: int) -> void:
	inst.bargained = true
	var rate: float = float(lv) * GameConfig.BARGAIN_RATE_PER_LEVEL
	if kind == "buy":
		var old_p: int = int(offer.get("offer_price", 0))
		var new_p: int = int(round(float(old_p) * (1.0 + rate)))
		offer["offer_price"] = new_p
		var lines: Array = GameConfig.BARGAIN_FLAVOR["sell"]
		_show_flavor_popup("议价 · 抬价成功", "%s\n\n买主出价 %d → %d 两。" % [str(lines[GameState.rng.randi() % lines.size()]), old_p, new_p])
	else:
		var old_a: int = int(offer.get("ask_price", 0))
		var new_a: int = max(1, int(round(float(old_a) * (1.0 - rate))))
		offer["ask_price"] = new_a
		var lines2: Array = GameConfig.BARGAIN_FLAVOR["buy"]
		_show_flavor_popup("议价 · 压价成功", "%s\n\n要价 %d → %d 两。" % [str(lines2[GameState.rng.randi() % lines2.size()]), old_a, new_a])
	_replace_offer_card(card, offer)

func _show_flavor_popup(title_text: String, text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title_text
	dlg.dialog_text = text
	dlg.ok_button_text = "知道了"
	dlg.get_label().add_theme_font_override("font", _cn_font)
	dlg.get_label().add_theme_font_size_override("font_size", 15)
	dlg.get_ok_button().add_theme_font_override("font", _cn_font)
	add_child(dlg)
	dlg.popup_centered(Vector2i(440, 240))
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())

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
		var level := _effective_level(inst2, int(offer.get("info_level", 1)))
		dlg.dialog_text = "%s\n要价：%d 两\n%s\n%s" % [_sell_title(inst2, level), int(offer.get("ask_price", 0)), _sell_info_text(inst2, level), _risk_text(inst2, level)]
	add_child(dlg)
	dlg.popup_centered()

func _show_purchase_result(inst: Resource, before_fragments: int, before_level: int, after_fragments: int, after_level: int) -> void:
	var dlg := TradeResultDialog.new()
	dlg.setup_purchase(inst, before_fragments, before_level, after_fragments, after_level)
	_present_result_and_close(dlg)

func _show_sale_result(inst: Resource, sale_price: int, paid_price: int) -> void:
	var dlg := TradeResultDialog.new()
	dlg.setup_sale(inst, sale_price, paid_price)
	_present_result_and_close(dlg)

## 交易完成后：把结算窗口挂到上层节点显示，并关闭选品界面（只留结算窗口）。
func _present_result_and_close(dlg: Window) -> void:
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(dlg)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	dlg.popup_centered()
	emit_signal("close_requested")

func _center_label(text: String, size_px: int, color: Color) -> Label:
	var lbl := _label(text, size_px, color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _effective_level(inst: Resource, base_level: int) -> int:
	return 3 if inst.appraisal_revealed else base_level

func _sell_title(inst: Resource, level: int) -> String:
	if inst.appraisal_revealed and inst.fake_detected:
		return "%s（赝品）" % inst.display_name()
	if level >= 3:
		return "%s（%s）" % [inst.display_name(), inst.def.rarity_label()]
	return inst.display_name()

func _visible_rarity_color(inst: Resource, level: int) -> Color:
	if inst.appraisal_revealed and inst.fake_detected:
		return Color("#d4503a")
	if level >= 3:
		return inst.rarity_color()
	return Color("#6f6860")

func _rarity_hint(inst: Resource, level: int) -> String:
	if inst.appraisal_revealed and inst.fake_detected:
		return "已鉴定：赝品！估价骤跌，慎入"
	if inst.appraisal_revealed:
		return "已鉴定：%s级 · 真品" % inst.def.rarity_label()
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
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)

	var coin := CoinIcon.make_icon(22)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)

	var label := _label("要价", 12, Color("#d8c6a3"), false)
	label.custom_minimum_size = Vector2(30, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

	# 位数越多字号越小，保证大额数字仍能与“两”留在同一排不换行。
	var price_str := str(price)
	var price_size := 22
	if price_str.length() >= 7:
		price_size = 14
	elif price_str.length() >= 6:
		price_size = 16
	elif price_str.length() >= 5:
		price_size = 19
	var price_lbl := _label(price_str, price_size, Color("#ffd166"), false)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
	price_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(price_lbl)

	var unit := _label("两", 12, Color("#d4a843"), false)
	unit.custom_minimum_size = Vector2(16, 0)
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
	panel.custom_minimum_size = Vector2(118, 156)
	var sb := StyleBoxFlat.new()
	sb.bg_color = inst.rarity_color().darkened(0.25) if level >= 3 else Color("#5b5650")
	sb.border_color = Color("#1f1610")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _label(inst.type_icon() if level >= 2 else "?", 46, Color("#f5e6c8"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _base_card(color: Color) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(280, 580)
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
	row.add_child(_label(label_text, 12, Color("#d8c6a3"), false))
	row.add_child(_coin_icon(18))
	var price_lbl := _label(str(amount), 15, color, false)
	price_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	price_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(price_lbl)
	row.add_child(_label("两", 12, Color("#d4a843"), false))
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
	chip.add_child(_label(label_text, 11, Color("#d8c6a3"), false))
	chip.add_child(_coin_icon(16))
	var amount_lbl := _label(str(amount), 13, color, false)
	amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	amount_lbl.add_theme_constant_override("outline_size", 1)
	chip.add_child(amount_lbl)
	return chip

func _coin_icon(size_px: int) -> TextureRect:
	return CoinIcon.make_icon(size_px)

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

func _label(text: String, size_px: int, color: Color, wrap: bool = true) -> Label:
	_ensure_font()
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	# 横排（HBox）里的短标签必须关掉自动换行，否则窄卡里汉字会逐字竖排错乱。
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return lbl
