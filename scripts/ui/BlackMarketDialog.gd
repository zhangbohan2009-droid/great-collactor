extends Window
## 黑市占位弹窗
## MVP 复用 CityDialog 的"刷文物 + 购买"逻辑，唯一区别：50% 假货风险（玩家鉴定不能 100% 识破）

const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const TradeResultDialog := preload("res://scripts/ui/TradeResultDialog.gd")
const CoinIcon := preload("res://scripts/ui/CoinIcon.gd")

var _tile = null
var _stock: Array = []
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
	size = Vector2i(920, 660)
	min_size = Vector2i(840, 580)
	transient = true
	exclusive = true
	always_on_top = true

func setup(tile) -> void:
	_tile = tile
	title = "黑市 · %s" % tile.display_name

func _ready() -> void:
	_ensure_font()
	_stock = GameFlow.get_bm_stock(_tile.index)
	_apply_market_peek()
	_build()

func _ensure_font() -> void:
	if _cn_font != null:
		return
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]

func _apply_market_peek() -> void:
	var human = GameState.human_player()
	if human == null or GameState.tool_count(human.id, "market_peek_card") <= 0:
		return
	if not GameState.consume_tool(human.id, "market_peek_card"):
		return
	var best := 0
	for inst in _stock:
		if inst != null and inst.has_method("rarity"):
			best = max(best, int(inst.rarity()))
	var label := GameConfig.RARITY_NAMES[best] if best > 0 and best < GameConfig.RARITY_NAMES.size() else "未知"
	EventBus.toast.emit("风闻：%s 暗摊最高可能有「%s」级货源" % [_tile.display_name, label], "info")

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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_label("黑市 · %s" % _tile.display_name, 20, Color("#c89aff")))
	root.add_child(_label("暗摊价格更狠，赝品也更多。卡片只展示商贩话术和暗价，真伪与真实价值需要谨慎判断。", 13, Color("#bfa7d8")))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	_grid = grid

	for inst in _stock:
		grid.add_child(_make_card(inst))
	if not GameState.can_trade_this_turn():
		_lock_trading()

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	var close_btn := _make_btn(_end_turn_button_text(), _end_turn_button_color())
	close_btn.custom_minimum_size = Vector2(230 if _will_enter_auction_after_close() else 130, 38)
	close_btn.tooltip_text = _end_turn_button_text()
	close_btn.pressed.connect(func(): emit_signal("close_requested"))
	bottom.add_child(close_btn)

func _make_card(inst: Resource) -> Panel:
	var human = GameState.human_player()
	var level := _effective_level(inst, MarketSystemRef.info_level_for_instance(inst, human))
	# 首次构卡时锁定暗价并持久化；之后鉴定/重建卡片都沿用同一价格（鉴定只改估值，不改买价）。
	if int(inst.negotiated_price) <= 0:
		inst.negotiated_price = MarketSystemRef.ask_price_for_player(inst, GameState.rng, human, true)
	var ask_price := int(inst.negotiated_price)
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

	var icon_center := CenterContainer.new()
	icon_center.add_child(_relic_icon(inst, level))
	vroot.add_child(icon_center)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	vroot.add_child(body)
	body.add_child(_label(_sell_title(inst, level), 18, Color("#f5e6c8")))
	var pitch_lbl := _label("%s：%s" % [_black_market_seller(inst), _black_market_pitch(inst, ask_price)], 13, Color("#d8c6a3"))
	pitch_lbl.custom_minimum_size = Vector2(0, 64)
	body.add_child(pitch_lbl)
	body.add_child(_price_row(ask_price))
	var risk_lbl := _label(_risk_hint(inst, level), 12, _visible_rarity_color(inst, level))
	body.add_child(risk_lbl)

	var skill_row := _skill_button_row(inst, card)
	if skill_row != null:
		vroot.add_child(skill_row)

	var btn_col := HBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	vroot.add_child(btn_col)
	var buy_btn := _make_btn("摸货", Color("#9b5ee0"))
	buy_btn.custom_minimum_size = Vector2(86, 30)
	btn_col.add_child(buy_btn)

	var data := { "inst": inst, "buy_btn": buy_btn, "info_lbl": risk_lbl, "ask_price": ask_price, "card": card }
	_cards.append(data)
	_trade_buttons.append(buy_btn)
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
	var before_fragments := int(human.history_fragments)
	var before_level := int(human.level)
	if GameFlow.human_buy_item(_tile.index, inst, price):
		var btn: Button = data["buy_btn"]
		btn.text = "已入手"
		var info: Label = data["info_lbl"]
		info.text = "已入手，藏品已收入仓库。"
		_lock_trading()
		human = GameState.human_player()
		var after_fragments := before_fragments if human == null else int(human.history_fragments)
		var after_level := before_level if human == null else int(human.level)
		_show_purchase_result(inst, before_fragments, before_level, after_fragments, after_level)

func _show_purchase_result(inst: Resource, before_fragments: int, before_level: int, after_fragments: int, after_level: int) -> void:
	var dlg := TradeResultDialog.new()
	dlg.setup_purchase(inst, before_fragments, before_level, after_fragments, after_level)
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

func _base_card(color: Color) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(205, 420)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#28172a")
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)
	return card

func _relic_icon(inst: Resource, level: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(90, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = inst.rarity_color().darkened(0.35) if level >= 3 else Color("#5b5650")
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

func _price_row(price: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.82)
	sb.border_color = Color("#5a3a78")
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
	row.add_child(CoinIcon.make_icon(22))
	var label := _label("暗价", 12, Color("#d8c6a3"), false)
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
	row.add_child(_label("两", 12, Color("#d4a843"), false))
	return box

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

func _risk_hint(inst: Resource, level: int) -> String:
	var human = GameState.human_player()
	if inst.appraisal_revealed and inst.fake_detected:
		return "已鉴定：赝品！估价骤跌，慎入"
	if inst.appraisal_revealed:
		return "已鉴定：%s级 · 真品，但黑市仍需留神" % inst.def.rarity_label()
	if human != null and human.skills.get("fake_sense", false) and inst.is_fake and GameState.rng.randf() < 0.25:
		return "黑市风险：疑似赝品"
	if level >= 3:
		return "已识别：%s级，但黑市仍有赝品风险" % inst.def.rarity_label()
	return "鉴赏不足：稀有度与真伪都看不稳"

func _replace_card(old_card: Panel, inst: Resource) -> void:
	if not is_instance_valid(old_card) or _grid == null:
		return
	var idx := old_card.get_index()
	var new_card := _make_card(inst)
	_grid.add_child(new_card)
	_grid.move_child(new_card, idx)
	old_card.queue_free()
	if not GameState.can_trade_this_turn():
		_lock_trading()

func _lock_trading() -> void:
	for b in _trade_buttons:
		if is_instance_valid(b):
			b.disabled = true

func _skill_button_row(inst: Resource, card: Panel) -> HBoxContainer:
	var buttons: Array = []
	if not inst.appraisal_revealed and GameState.rng.randf() < 0.5:
		buttons.append(_appraisal_button(inst, card))
	if not inst.bargained and GameState.rng.randf() < 0.5:
		buttons.append(_bargain_button(inst, card))
	if buttons.is_empty():
		return null
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for b in buttons:
		row.add_child(b)
	return row

func _appraisal_button(inst: Resource, card: Panel) -> Button:
	var lv: int = GameState.appraisal_skill_level(GameState.human_player())
	var b := _make_btn("鉴定真伪", Color("#7da8d4"))
	b.custom_minimum_size = Vector2(98, 28)
	if lv <= 0:
		b.disabled = true
		b.tooltip_text = "需要解锁『真伪鉴定』技能"
	else:
		b.tooltip_text = "动用眼力鉴定真伪并收窄估值（Lv.%d）" % lv
		b.pressed.connect(func(): _use_appraisal(inst, card, lv))
	return b

func _bargain_button(inst: Resource, card: Panel) -> Button:
	var lv: int = GameState.bargain_skill_level(GameState.human_player())
	var b := _make_btn("议价压价", Color("#9bd47a"))
	b.custom_minimum_size = Vector2(98, 28)
	if lv <= 0:
		b.disabled = true
		b.tooltip_text = "需要解锁『议价』技能"
	else:
		var pct: int = int(round(float(lv) * GameConfig.BARGAIN_RATE_PER_LEVEL * 100.0))
		b.tooltip_text = "压低暗价（Lv.%d，约 %d%%）" % [lv, pct]
		b.pressed.connect(func(): _use_bargain(inst, card, lv))
	return b

func _use_appraisal(inst: Resource, card: Panel, lv: int) -> void:
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
	_replace_card(card, inst)

func _use_bargain(inst: Resource, card: Panel, lv: int) -> void:
	inst.bargained = true
	var old_price: int = MarketSystemRef.ask_price_for_player(inst, GameState.rng, GameState.human_player(), true)
	var rate: float = float(lv) * GameConfig.BARGAIN_RATE_PER_LEVEL
	var new_price: int = max(1, int(round(float(old_price) * (1.0 - rate))))
	inst.negotiated_price = new_price
	var lines: Array = GameConfig.BARGAIN_FLAVOR["buy"]
	_show_flavor_popup("议价 · 压价成功", "%s\n\n暗价 %d → %d 两。" % [str(lines[GameState.rng.randi() % lines.size()]), old_price, new_price])
	_replace_card(card, inst)

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

func _black_market_seller(inst: Resource) -> String:
	var sellers := ["暗摊老板", "蒙面货主", "夜市牙人", "走水客"]
	return sellers[abs(hash(inst.display_name())) % sellers.size()]

func _black_market_pitch(inst: Resource, ask_price: int) -> String:
	match inst.rarity():
		1:
			return "小物件不多问来路，今晚 %d 两拿走。" % ask_price
		2:
			return "这东西有点眼力才敢收，暗价 %d 两。" % ask_price
		3:
			return "白天不敢摆，夜里才出手，%d 两别声张。" % ask_price
		_:
			return "压着消息来的硬货，错过就没了，%d 两。" % ask_price

func _make_btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _cn_font)
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

func _label(text: String, size_px: int, color: Color, wrap: bool = true) -> Label:
	_ensure_font()
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return lbl
