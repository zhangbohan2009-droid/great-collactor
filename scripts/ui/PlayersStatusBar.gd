extends Control
## 左上简化同步面板：玩家 ready 状态 + 最新骰点。

var _rows: Dictionary = {}    # player_id -> { root, name_label, dice_label, check }
var _last_dice: Dictionary = {}
var _rows_box: VBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(330, 150)
	size = Vector2(330, 150)

func _ready() -> void:
	_build()
	_refresh_all()
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.player_ready_changed.connect(_on_ready_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.dice_rolled.connect(_on_dice_rolled)

func _build() -> void:
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.70)
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	bg.add_theme_stylebox_override("panel", sb)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.anchor_right = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	add_child(vbox)

	var title := Label.new()
	title.text = "同步状态"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("#a89a82"))
	vbox.add_child(title)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_rows_box)
	for p in _ranked_players():
		var row := _make_row(p)
		_rows_box.add_child(row["root"])
		_rows[p.id] = row

func _make_row(player) -> Dictionary:
	var root := Panel.new()
	root.custom_minimum_size = Vector2(306, 30)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("#1f1610")
	rsb.border_color = player.color
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(8)
	root.add_theme_stylebox_override("panel", rsb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 8
	row.offset_top = 4
	row.offset_right = -8
	row.offset_bottom = -4
	root.add_child(row)

	var rank_lbl := Label.new()
	rank_lbl.text = "#?"
	rank_lbl.custom_minimum_size = Vector2(28, 0)
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	row.add_child(rank_lbl)

	row.add_child(_avatar_badge(player))

	var name_lbl := Label.new()
	name_lbl.text = player.display_name + ("（你）" if player.id == GameConfig.HUMAN_PLAYER_ID else "")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var total_lbl := Label.new()
	total_lbl.custom_minimum_size = Vector2(66, 0)
	total_lbl.add_theme_font_size_override("font_size", 11)
	total_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	row.add_child(total_lbl)

	var dice_lbl := Label.new()
	dice_lbl.text = "骰：—"
	dice_lbl.custom_minimum_size = Vector2(44, 0)
	dice_lbl.add_theme_font_size_override("font_size", 12)
	dice_lbl.add_theme_color_override("font_color", Color("#d4a843"))
	row.add_child(dice_lbl)

	var check := Label.new()
	check.text = "等待"
	check.custom_minimum_size = Vector2(42, 0)
	check.add_theme_font_size_override("font_size", 12)
	check.add_theme_color_override("font_color", Color("#7d6a4a"))
	row.add_child(check)

	return { "root": root, "rank_label": rank_lbl, "name_label": name_lbl, "total_label": total_lbl, "dice_label": dice_lbl, "check": check }

func _avatar_badge(player) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(22, 22)
	badge.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = player.color.darkened(0.1)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	badge.add_theme_stylebox_override("panel", sb)
	var avatar := TextureRect.new()
	avatar.texture = load(str(GameConfig.AVATAR_TEXTURES.get(player.avatar_id, GameConfig.AVATAR_TEXTURES["collector_gold"])))
	avatar.anchor_right = 1.0
	avatar.anchor_bottom = 1.0
	avatar.offset_left = 2
	avatar.offset_top = 2
	avatar.offset_right = -2
	avatar.offset_bottom = -2
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	badge.add_child(avatar)
	return badge

func _refresh_all() -> void:
	if _rows_box != null:
		for child in _rows_box.get_children():
			_rows_box.remove_child(child)
			child.queue_free()
		_rows.clear()
		for p in _ranked_players():
			var row := _make_row(p)
			_rows_box.add_child(row["root"])
			_rows[p.id] = row
	for p in _ranked_players():
		_refresh_player(p)

func _refresh_player(player) -> void:
	if not _rows.has(player.id):
		return
	var row: Dictionary = _rows[player.id]
	var rank_label: Label = row["rank_label"]
	rank_label.text = "#%d" % _rank_for_player(player.id)
	var total_label: Label = row["total_label"]
	total_label.text = "%d" % GameState.total_assets(player)
	var dice_label: Label = row["dice_label"]
	dice_label.text = "骰：%s" % str(_last_dice.get(player.id, "—"))
	var check: Label = row["check"]
	if _is_ready_phase():
		if player.ready:
			check.text = "✓"
			check.add_theme_color_override("font_color", Color("#9bd47a"))
		else:
			check.text = "等待"
			check.add_theme_color_override("font_color", Color("#7d6a4a"))
	else:
		check.text = GameConfig.PHASE_NAMES.get(GameState.current_phase, GameState.current_phase)
		check.add_theme_color_override("font_color", Color("#4d4438"))

func _is_ready_phase() -> bool:
	return ["dice", "move", "event"].has(GameState.current_phase)

func _on_money_changed(player_id: int, _amount: int) -> void:
	_refresh_all()

func _on_item_acquired(_player_id: int, _inst) -> void:
	_refresh_all()

func _on_ready_changed(player_id: int, _ready: bool, _phase: String) -> void:
	var p = GameState.get_player(player_id)
	if p:
		_refresh_player(p)

func _on_phase_changed(_p: String) -> void:
	if _p == "dice":
		_last_dice.clear()
	_refresh_all()

func _on_dice_rolled(player_id: int, value: int) -> void:
	_last_dice[player_id] = value
	var p = GameState.get_player(player_id)
	if p:
		_refresh_player(p)

func _ranked_players() -> Array:
	var ranked := GameState.ranking_data()
	var result: Array = []
	for row in ranked:
		var p = GameState.get_player(int(row.get("player_id", -1)))
		if p != null:
			result.append(p)
	return result

func _rank_for_player(player_id: int) -> int:
	var ranked := GameState.ranking_data()
	for i in range(ranked.size()):
		if int(ranked[i].get("player_id", -1)) == player_id:
			return i + 1
	return 0
