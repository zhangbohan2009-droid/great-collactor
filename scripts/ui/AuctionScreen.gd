extends Control
## 拍卖屏：3 件拍品依次竞价
## 同一件拍品中：起拍 → 玩家 vs 2 AI 轮流出价 → 一人剩下时落槌
## MVP 简化为：每轮先 AI1 出 → AI2 出 → 等玩家加价 / 放弃；玩家放弃即结束本件

const AuctionSystemRef := preload("res://scripts/systems/AuctionSystem.gd")
const AISystemRef := preload("res://scripts/systems/AISystem.gd")
const AUCTION_SCENE_BG := "res://assets/art/key/auction_scene_bg.png"

var session: Dictionary = {}

var _title_lbl: Label
var _lot_index_lbl: Label
var _item_name_lbl: Label
var _item_info_lbl: Label
var _lot_card: Panel
var _icon_panel: Panel
var _icon_lbl: Label
var _current_bid_lbl: Label
var _leader_lbl: Label
var _auctioneer_lbl: Label
var _auctioneer_hint_lbl: Label
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _bid_btn: Button
var _withdraw_btn: Button
var _exit_session_btn: Button
var _next_btn: Button
var _bidder_panels: Dictionary = {}    # player_id -> { panel, money_lbl, status_lbl }

var _running_lot: bool = false
var _ai_pumping: bool = false
var _human_left_session: bool = false

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

func _ready() -> void:
	if GameConfig.DEBUG_AUTOPLAY:
		print("[auction] ready, lots=%d" % session.get("lots", []).size())
	_build()
	# 给 UI 上场一点时间，再开始第一件
	_show_start_banner()
	await get_tree().create_timer(1.0).timeout
	_start_current_lot()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1a1208")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var scene_bg := TextureRect.new()
	scene_bg.texture = _load_png_texture(AUCTION_SCENE_BG)
	scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene_bg.modulate = Color(0.96, 0.90, 0.80, 1.0)
	scene_bg.anchor_right = 1.0
	scene_bg.anchor_bottom = 1.0
	add_child(scene_bg)

	var bg_shade := ColorRect.new()
	bg_shade.color = Color(0.05, 0.025, 0.012, 0.44)
	bg_shade.anchor_right = 1.0
	bg_shade.anchor_bottom = 1.0
	add_child(bg_shade)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# 顶部标题栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)

	_title_lbl = Label.new()
	_title_lbl.text = "第 %d 回合 · 拍卖会" % int(session.get("round_num", 0))
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	top.add_child(_title_lbl)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	_lot_index_lbl = Label.new()
	_lot_index_lbl.text = "—"
	_lot_index_lbl.add_theme_font_size_override("font_size", 16)
	_lot_index_lbl.add_theme_color_override("font_color", Color("#a89a82"))
	top.add_child(_lot_index_lbl)

	# 中间主区：左侧拍品卡片 + 右侧出价 log
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	# === 左侧 拍品 ===
	_lot_card = Panel.new()
	_lot_card.custom_minimum_size = Vector2(470, 520)
	_lot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lot_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color("#2a1f15")
	lsb.border_color = Color("#5a4630")
	lsb.set_border_width_all(2)
	lsb.set_corner_radius_all(12)
	lsb.shadow_color = Color(0, 0, 0, 0.38)
	lsb.shadow_size = 8
	_lot_card.add_theme_stylebox_override("panel", lsb)
	middle.add_child(_lot_card)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lv.anchor_right = 1.0
	lv.anchor_bottom = 1.0
	lv.offset_left = 14
	lv.offset_top = 14
	lv.offset_right = -14
	lv.offset_bottom = -14
	_lot_card.add_child(lv)

	# 拍品图标 + 名称
	var item_head := HBoxContainer.new()
	item_head.add_theme_constant_override("separation", 12)
	lv.add_child(item_head)

	_icon_panel = Panel.new()
	_icon_panel.custom_minimum_size = Vector2(80, 80)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("#6a6058")
	isb.set_corner_radius_all(4)
	_icon_panel.add_theme_stylebox_override("panel", isb)
	_icon_lbl = Label.new()
	_icon_lbl.text = "?"
	_icon_lbl.add_theme_font_size_override("font_size", 42)
	_icon_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	_icon_lbl.anchor_right = 1.0
	_icon_lbl.anchor_bottom = 1.0
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_panel.add_child(_icon_lbl)
	item_head.add_child(_icon_panel)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 4)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_head.add_child(name_box)

	_item_name_lbl = Label.new()
	_item_name_lbl.text = "—"
	_item_name_lbl.add_theme_font_size_override("font_size", 22)
	_item_name_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	_item_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_name_lbl.custom_minimum_size = Vector2(0, 54)
	name_box.add_child(_item_name_lbl)

	_item_info_lbl = Label.new()
	_item_info_lbl.text = "拍卖师正在验看拍品"
	_item_info_lbl.add_theme_font_size_override("font_size", 14)
	_item_info_lbl.add_theme_color_override("font_color", Color("#a89a82"))
	_item_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(_item_info_lbl)

	# 当前价 + leader
	var auctioneer_panel := Panel.new()
	auctioneer_panel.custom_minimum_size = Vector2(0, 116)
	auctioneer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color("#1f1610")
	asb.border_color = Color("#d4a843")
	asb.set_border_width_all(2)
	asb.set_corner_radius_all(10)
	asb.content_margin_left = 14
	asb.content_margin_right = 14
	asb.content_margin_top = 10
	asb.content_margin_bottom = 10
	auctioneer_panel.add_theme_stylebox_override("panel", asb)
	lv.add_child(auctioneer_panel)

	var av := VBoxContainer.new()
	av.anchor_right = 1.0
	av.anchor_bottom = 1.0
	av.offset_left = 12
	av.offset_top = 8
	av.offset_right = -12
	av.offset_bottom = -8
	auctioneer_panel.add_child(av)

	_auctioneer_lbl = Label.new()
	_auctioneer_lbl.text = "拍卖主：诸位请看台上宝物。"
	_auctioneer_lbl.add_theme_font_size_override("font_size", 17)
	_auctioneer_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	_auctioneer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auctioneer_lbl.custom_minimum_size = Vector2(0, 58)
	av.add_child(_auctioneer_lbl)

	_auctioneer_hint_lbl = Label.new()
	_auctioneer_hint_lbl.text = "举牌跟价，或放弃退席。"
	_auctioneer_hint_lbl.add_theme_font_size_override("font_size", 12)
	_auctioneer_hint_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	av.add_child(_auctioneer_hint_lbl)

	var bid_row := HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 16)
	bid_row.custom_minimum_size = Vector2(0, 40)
	lv.add_child(bid_row)

	_current_bid_lbl = Label.new()
	_current_bid_lbl.text = "当前叫价  0 两"
	_current_bid_lbl.add_theme_font_size_override("font_size", 26)
	_current_bid_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	bid_row.add_child(_current_bid_lbl)

	_leader_lbl = Label.new()
	_leader_lbl.text = "暂无领先"
	_leader_lbl.add_theme_font_size_override("font_size", 16)
	_leader_lbl.add_theme_color_override("font_color", Color("#9bd47a"))
	bid_row.add_child(_leader_lbl)

	# 出价按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.custom_minimum_size = Vector2(0, 46)
	lv.add_child(btn_row)

	_bid_btn = _make_btn("举牌应价（+%d）" % GameConfig.AUCTION_MIN_BID_STEP, Color("#d4a843"))
	_bid_btn.custom_minimum_size = Vector2(170, 42)
	_bid_btn.add_theme_font_size_override("font_size", 16)
	_bid_btn.pressed.connect(_on_player_bid)
	btn_row.add_child(_bid_btn)

	_withdraw_btn = _make_btn("放下号牌", Color("#b03020"))
	_withdraw_btn.custom_minimum_size = Vector2(120, 42)
	_withdraw_btn.add_theme_font_size_override("font_size", 16)
	_withdraw_btn.pressed.connect(_on_player_withdraw)
	btn_row.add_child(_withdraw_btn)

	_exit_session_btn = _make_btn("退出本次拍卖", Color("#7d6a4a"))
	_exit_session_btn.custom_minimum_size = Vector2(150, 42)
	_exit_session_btn.add_theme_font_size_override("font_size", 15)
	_exit_session_btn.tooltip_text = "退出整场拍卖会；确认后本场剩余拍品由其他玩家继续竞拍"
	_exit_session_btn.pressed.connect(_confirm_exit_session)
	btn_row.add_child(_exit_session_btn)

	_next_btn = _make_btn("请下一件 / 收场", Color("#7da8d4"))
	_next_btn.custom_minimum_size = Vector2(150, 40)
	_next_btn.add_theme_font_size_override("font_size", 16)
	_next_btn.visible = false
	_next_btn.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_btn)

	# 三人出价状态条
	var bidders_box := HBoxContainer.new()
	bidders_box.add_theme_constant_override("separation", 8)
	bidders_box.custom_minimum_size = Vector2(0, 66)
	lv.add_child(bidders_box)
	for p in GameState.players:
		var panel := _make_bidder_panel(p)
		bidders_box.add_child(panel["root"])
		_bidder_panels[p.id] = panel

	# === 右侧 出价 LOG ===
	var right := Panel.new()
	right.custom_minimum_size = Vector2(300, 360)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("#1f1610")
	rsb.border_color = Color("#5a4630")
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(6)
	right.add_theme_stylebox_override("panel", rsb)
	middle.add_child(right)

	var rv := VBoxContainer.new()
	rv.anchor_right = 1.0
	rv.anchor_bottom = 1.0
	rv.offset_left = 12
	rv.offset_top = 12
	rv.offset_right = -12
	rv.offset_bottom = -12
	right.add_child(rv)

	var rhead := Label.new()
	rhead.text = "出价记录"
	rhead.add_theme_font_size_override("font_size", 16)
	rhead.add_theme_color_override("font_color", Color("#a89a82"))
	rv.add_child(rhead)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_log_scroll)

	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 4)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

func _make_btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	var sbh := sb.duplicate()
	sbh.bg_color = color.darkened(0.25)
	var sbd := sb.duplicate()
	sbd.bg_color = Color("#3a2e22")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	b.add_theme_color_override("font_disabled_color", Color("#7d6a4a"))
	return b

func _load_png_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _show_start_banner() -> void:
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -58
	panel.offset_right = 210
	panel.offset_bottom = 58
	panel.z_index = 50
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.90)
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var lbl := Label.new()
	lbl.text = "拍卖会开始"
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color("#d4a843"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	panel.add_child(lbl)
	var tween := create_tween()
	tween.tween_interval(0.65)
	tween.tween_property(panel, "modulate:a", 0.0, 0.28)
	tween.tween_callback(panel.queue_free)

func _make_bidder_panel(player) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 60)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = player.color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 8
	v.offset_top = 6
	v.offset_right = -8
	v.offset_bottom = -6
	panel.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = player.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	v.add_child(name_lbl)

	var money_lbl := Label.new()
	money_lbl.text = "%d 两" % player.money
	money_lbl.add_theme_font_size_override("font_size", 12)
	money_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	v.add_child(money_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "在场"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color("#9bd47a"))
	v.add_child(status_lbl)

	return { "root": panel, "money_lbl": money_lbl, "status_lbl": status_lbl }

# -----------------------------------------------------
# 单件拍品流程
# -----------------------------------------------------
func _start_current_lot() -> void:
	var lot := AuctionSystemRef.current_lot(session)
	if lot.is_empty():
		if GameConfig.DEBUG_AUTOPLAY:
			print("[auction] no more lots, finishing")
		_finish_session()
		return
	if GameConfig.DEBUG_AUTOPLAY:
		print("[auction] start lot idx=%d real=%d" % [int(session.get("current_lot", 0)), int(lot["instance"].real_price)])
	_running_lot = true
	_ai_pumping = false
	# 重置 UI
	var inst: Resource = lot["instance"]
	var item: Resource = lot["item"]
	_icon_lbl.text = item.type_icon()
	# 拍卖场已知稀有度
	var isb := StyleBoxFlat.new()
	isb.bg_color = item.rarity_color().darkened(0.2)
	isb.set_corner_radius_all(4)
	_icon_panel.add_theme_stylebox_override("panel", isb)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color("#2a1f15")
	card_sb.border_color = item.rarity_color()
	card_sb.set_border_width_all(3)
	card_sb.set_corner_radius_all(12)
	card_sb.shadow_color = Color(0, 0, 0, 0.42)
	card_sb.shadow_size = 8
	_lot_card.add_theme_stylebox_override("panel", card_sb)
	_item_name_lbl.text = "%s（%s）" % [item.display_name, item.rarity_label()]
	_item_info_lbl.text = "估价 %d – %d 两  ·  起拍 %d 两" % [inst.appraised_low, inst.appraised_high, int(lot["start_bid"])]
	_current_bid_lbl.text = "起拍价  %d 两" % int(lot["start_bid"])
	_leader_lbl.text = "暂无领先"
	_lot_index_lbl.text = "第 %d / %d 件" % [int(session.get("current_lot", 0)) + 1, session["lots"].size()]
	_clear_log()
	_log("司仪上台：本场第 %d 件 — %s。" % [int(session.get("current_lot", 0)) + 1, item.display_name], "head")
	_log("起拍价 %d 两。" % int(lot["start_bid"]), "muted")
	_say_auctioneer(_opening_line(item, lot), "等待第一位买家举牌。")

	# 把 current_bid 初始化为 start_bid，但 leader=-1（视为未有人正式出价）
	lot["current_bid"] = int(lot["start_bid"])
	lot["leader_id"] = -1
	lot["active_bidders"] = []
	for p in GameState.players:
		if _human_left_session and p.id == GameConfig.HUMAN_PLAYER_ID:
			continue
		lot["active_bidders"].append(p.id)

	_refresh_bidder_panels(lot)
	_refresh_buttons(lot)
	_next_btn.visible = false
	if _human_left_session:
		_say_auctioneer(_opening_line(item, lot), "你已退出本场拍卖，等待其他玩家竞拍完毕。")

	# 启动 AI 出价循环
	_ai_round(lot)

func _refresh_bidder_panels(lot: Dictionary) -> void:
	var active: Array = lot["active_bidders"]
	for p in GameState.players:
		if not _bidder_panels.has(p.id):
			continue
		var panel: Dictionary = _bidder_panels[p.id]
		var money_lbl: Label = panel["money_lbl"]
		var status_lbl: Label = panel["status_lbl"]
		money_lbl.text = "%d 两" % p.money
		if _human_left_session and p.id == GameConfig.HUMAN_PLAYER_ID:
			status_lbl.text = "已离场"
			status_lbl.add_theme_color_override("font_color", Color("#7d6a4a"))
		elif not active.has(p.id):
			status_lbl.text = "已弃拍"
			status_lbl.add_theme_color_override("font_color", Color("#7d6a4a"))
		elif lot.get("leader_id", -1) == p.id:
			status_lbl.text = "领先"
			status_lbl.add_theme_color_override("font_color", Color("#d4a843"))
		else:
			status_lbl.text = "在场"
			status_lbl.add_theme_color_override("font_color", Color("#9bd47a"))

func _refresh_buttons(lot: Dictionary) -> void:
	var active: Array = lot["active_bidders"]
	var human_in: bool = active.has(GameConfig.HUMAN_PLAYER_ID)
	var human = GameState.human_player()
	var min_bid: int = AuctionSystemRef.next_min_bid(lot)
	var can_bid: bool = not _human_left_session and human_in and human != null and human.money >= min_bid and not lot.get("finished", false)
	_bid_btn.disabled = not can_bid
	_bid_btn.text = "举牌应价  →  %d 两" % min_bid
	_withdraw_btn.disabled = _human_left_session or not human_in or lot.get("finished", false)
	_exit_session_btn.disabled = _human_left_session or bool(session.get("finished", false))

func _say_auctioneer(line: String, hint: String = "") -> void:
	if _auctioneer_lbl != null:
		_auctioneer_lbl.text = "拍卖主：%s" % line
	if _auctioneer_hint_lbl != null:
		_auctioneer_hint_lbl.text = hint

func _opening_line(item: Resource, lot: Dictionary) -> String:
	return "诸位掌眼，%s，%s级好物，起拍 %d 两。" % [item.display_name, item.rarity_label(), int(lot["start_bid"])]

func _bid_call_line(player_name: String, amount: int) -> String:
	var lines := [
		"%s 举牌，%d 两！还有没有更高的？",
		"%s 出到 %d 两，场上价已经起来了！",
		"%s 应价 %d 两，诸位可要跟？",
	]
	return lines[amount % lines.size()] % [player_name, amount]

func _hammer_line(lot: Dictionary) -> String:
	var price := int(lot.get("final_price", lot.get("current_bid", 0)))
	return "%d 两一次，%d 两两次，落槌！" % [price, price]

func _clear_log() -> void:
	for c in _log_box.get_children():
		c.queue_free()

func _log(text: String, tone: String = "normal") -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match tone:
		"head": lbl.add_theme_color_override("font_color", Color("#d4a843"))
		"player": lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
		"ai": lbl.add_theme_color_override("font_color", Color("#7da8d4"))
		"win": lbl.add_theme_color_override("font_color", Color("#9bd47a"))
		"lose": lbl.add_theme_color_override("font_color", Color("#e76a4a"))
		"muted": lbl.add_theme_color_override("font_color", Color("#a89a82"))
		_: lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	_log_box.add_child(lbl)
	# 自动滚到底
	await get_tree().process_frame
	if _log_scroll != null:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

# -----------------------------------------------------
# AI 出价（一轮 = 所有 AI 各决策一次）
# -----------------------------------------------------
func _ai_round(lot: Dictionary) -> void:
	if _ai_pumping or not _running_lot or lot.get("finished", false):
		return
	_ai_pumping = true
	var active: Array = lot["active_bidders"]
	var any_bid: bool = false
	for p in GameState.players:
		if not p.is_ai:
			continue
		if not active.has(p.id):
			continue
		if lot.get("leader_id", -1) == p.id:
			continue
		await get_tree().create_timer(randf_range(0.5, 1.1)).timeout
		if not _running_lot or lot.get("finished", false):
			_ai_pumping = false
			return
		var ceiling: int = int(lot["ceilings"].get(p.id, 0))
		var bid: int = AISystemRef.decide_auction_bid(p, int(lot["current_bid"]), ceiling, GameConfig.AUCTION_MIN_BID_STEP)
		if bid > 0:
			AuctionSystemRef.place_bid(lot, p.id, bid)
			_current_bid_lbl.text = "当前叫价  %d 两" % bid
			_leader_lbl.text = "%s 领先" % p.display_name
			_log("%s 抬手叫到 %d 两。" % [p.display_name, bid], "ai")
			_say_auctioneer(_bid_call_line(p.display_name, bid), "你可以举牌跟价，也可以放下号牌。")
			any_bid = true
		else:
			AuctionSystemRef.withdraw(lot, p.id)
			_log("%s 摇头退席。" % p.display_name, "muted")
			_say_auctioneer("%s 退了，场上还剩几家？" % p.display_name, "观察对手钱包，别被气氛带过头。")
		_refresh_bidder_panels(lot)
		_refresh_buttons(lot)
		await get_tree().process_frame
	_ai_pumping = false

	# AI 一轮结束后看是否能落槌
	if _check_finalize(lot):
		return
	# 没人出价且玩家也不在场 → 强行落槌
	if not lot["active_bidders"].has(GameConfig.HUMAN_PLAYER_ID):
		# 玩家弃拍后，AI 内部继续战
		if any_bid:
			_ai_round(lot)
		else:
			_force_finalize(lot)
		return
	# 玩家在场 → 等玩家操作（或 AUTOPLAY 模式下自动决策）
	_refresh_buttons(lot)
	if GameConfig.DEBUG_AUTOPLAY:
		_autoplay_human_bid(lot)

func _autoplay_human_bid(lot: Dictionary) -> void:
	await get_tree().create_timer(randf_range(0.4, 0.9)).timeout
	if not _running_lot or lot.get("finished", false):
		return
	if not lot["active_bidders"].has(GameConfig.HUMAN_PLAYER_ID):
		return
	var human = GameState.human_player()
	if human == null:
		return
	var ceiling: int = AISystemRef.make_auction_ceiling(int(lot["instance"].real_price), GameState.rng)
	var current: int = int(lot["current_bid"])
	var bid: int = AISystemRef.decide_auction_bid(human, current, ceiling, GameConfig.AUCTION_MIN_BID_STEP)
	if bid > 0:
		_on_player_bid()
	else:
		_on_player_withdraw()

func _on_player_bid() -> void:
	var lot := AuctionSystemRef.current_lot(session)
	if lot.is_empty() or lot.get("finished", false):
		return
	if not lot["active_bidders"].has(GameConfig.HUMAN_PLAYER_ID):
		return
	var min_bid: int = AuctionSystemRef.next_min_bid(lot)
	if AuctionSystemRef.place_bid(lot, GameConfig.HUMAN_PLAYER_ID, min_bid):
		_current_bid_lbl.text = "当前叫价  %d 两" % min_bid
		_leader_lbl.text = "你 领先"
		_log("你 加到 %d 两。" % min_bid, "player")
		_say_auctioneer(_bid_call_line("这位藏家", min_bid), "拍卖主看向其他买家，等他们跟价。")
		_refresh_bidder_panels(lot)
		_refresh_buttons(lot)
		if _check_finalize(lot):
			return
		# 玩家叫完，下一轮 AI 继续
		_ai_round(lot)

func _on_player_withdraw() -> void:
	var lot := AuctionSystemRef.current_lot(session)
	if lot.is_empty() or lot.get("finished", false):
		return
	if not lot["active_bidders"].has(GameConfig.HUMAN_PLAYER_ID):
		return
	AuctionSystemRef.withdraw(lot, GameConfig.HUMAN_PLAYER_ID)
	_log("你 放下号牌。", "muted")
	_say_auctioneer("这位藏家暂且收手，买卖不急，眼力要稳。", "剩余买家会继续争夺本件拍品。")
	_refresh_bidder_panels(lot)
	_refresh_buttons(lot)
	if _check_finalize(lot):
		return
	# 让 AI 继续抢
	_ai_round(lot)

func _confirm_exit_session() -> void:
	if _human_left_session:
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "退出本次拍卖"
	dlg.dialog_text = "确认退出本次拍卖会？\n\n退出后你将离开整场拍卖，不能参与剩余拍品。其他玩家会继续竞拍，结束后自动进入下一回合。"
	dlg.ok_button_text = "确认退出"
	dlg.cancel_button_text = "继续竞拍"
	dlg.confirmed.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
		_exit_session()
	)
	dlg.canceled.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()

func _exit_session() -> void:
	_human_left_session = true
	_bid_btn.disabled = true
	_withdraw_btn.disabled = true
	_exit_session_btn.disabled = true
	_log("你 退出本次拍卖会，等待其他买家完成竞拍。", "muted")
	_say_auctioneer("这位藏家先行离席，余下拍品继续开槌。", "你已退出本场拍卖，等待系统自动进入下一回合。")
	var lot := AuctionSystemRef.current_lot(session)
	if lot.is_empty():
		return
	if not lot.get("finished", false):
		if int(lot.get("leader_id", -1)) == GameConfig.HUMAN_PLAYER_ID:
			lot["leader_id"] = -1
			lot["current_bid"] = int(lot.get("start_bid", GameConfig.AUCTION_MIN_BID_STEP))
			_current_bid_lbl.text = "起拍价  %d 两" % int(lot["current_bid"])
			_leader_lbl.text = "暂无领先"
			_log("你离场，当前领先出价作废，本件回到起拍价。", "muted")
		if lot["active_bidders"].has(GameConfig.HUMAN_PLAYER_ID):
			AuctionSystemRef.withdraw(lot, GameConfig.HUMAN_PLAYER_ID)
		_refresh_bidder_panels(lot)
		_refresh_buttons(lot)
		if _check_finalize(lot):
			return
		if not _ai_pumping:
			_ai_round(lot)
	else:
		_next_btn.visible = false
		_auto_advance_after_exit()

## 检查并触发落槌；返回是否已结
func _check_finalize(lot: Dictionary) -> bool:
	var active: Array = lot["active_bidders"]
	# 只剩 leader 一个 → 落槌
	if lot.get("leader_id", -1) != -1 and active.size() <= 1 and active.has(lot["leader_id"]):
		_force_finalize(lot)
		return true
	# 全弃拍且无 leader → 流拍
	if active.is_empty():
		_force_finalize(lot)
		return true
	return false

func _force_finalize(lot: Dictionary) -> void:
	if lot.get("finished", false):
		return
	var result := AuctionSystemRef.try_finalize(lot)
	var winner_id: int = int(result.get("winner_id", -1))
	var final_price: int = int(result.get("final_price", 0))
	if GameConfig.DEBUG_AUTOPLAY:
		print("[auction] finalize lot winner=%d price=%d" % [winner_id, final_price])
	if winner_id == -1 or final_price <= 0:
		_log("无人出价，本件流拍。", "muted")
		_say_auctioneer("无人应价，本件暂且收回。", "点击下一件继续。")
	else:
		var p = GameState.get_player(winner_id)
		if p != null:
			if GameState.change_money(winner_id, -final_price, "拍得 %s" % lot["item"].display_name):
				lot["instance"].paid_price = final_price
				lot["instance"].acquired_round = GameState.current_round
				lot["instance"].acquired_from = "第 %d 回合拍卖会" % GameState.current_round
				GameState.add_item_to_player(winner_id, lot["instance"])
				_award_auction_history(winner_id, lot, final_price)
				if winner_id == GameConfig.HUMAN_PLAYER_ID:
					_log("落槌！你以 %d 两拍得 %s。" % [final_price, lot["item"].display_name], "win")
				else:
					_log("落槌！%s 以 %d 两拍走 %s。" % [p.display_name, final_price, lot["item"].display_name], "lose")
				_say_auctioneer(_hammer_line(lot), "本件成交，点击下一件继续。")
			else:
				_log("赢家银两不足，本件作废。", "muted")
	_refresh_bidder_panels(lot)
	_bid_btn.disabled = true
	_withdraw_btn.disabled = true
	_exit_session_btn.disabled = _human_left_session
	_next_btn.visible = not _human_left_session
	_running_lot = false
	if _human_left_session:
		_auto_advance_after_exit()
	if GameConfig.DEBUG_AUTOPLAY:
		_autoplay_advance_after_finalize()

func _award_auction_history(winner_id: int, lot: Dictionary, final_price: int) -> void:
	var inst: Resource = lot.get("instance", null)
	if inst == null:
		return
	var amount: int = 30 + inst.rarity() * 15
	if winner_id == GameConfig.HUMAN_PLAYER_ID and final_price < int(lot.get("estimate", 0)) * 0.8:
		amount += 40
	GameState.add_history_fragments(winner_id, amount, "拍得 %s" % inst.display_name())

func _on_next_pressed() -> void:
	var still := AuctionSystemRef.next_lot(session)
	if still:
		_start_current_lot()
	else:
		_finish_session()

func _auto_advance_after_exit() -> void:
	await get_tree().create_timer(0.8).timeout
	if not _human_left_session:
		return
	if _running_lot:
		return
	_on_next_pressed()

# AUTOPLAY 时落槌后自动点 "下一件"
func _autoplay_advance_after_finalize() -> void:
	await get_tree().create_timer(0.6).timeout
	if not GameConfig.DEBUG_AUTOPLAY:
		return
	_on_next_pressed()

func _finish_session() -> void:
	_log("拍卖会结束。", "head")
	await get_tree().create_timer(0.8).timeout
	GameFlow.notify_auction_finished()
