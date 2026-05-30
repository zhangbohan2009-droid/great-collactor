extends Window
## 个人主页：属性展示 + 技能树加点。

var _tabs: TabContainer
var _attr_page: ScrollContainer
var _skill_page: ScrollContainer
var _cn_font: SystemFont

func _init() -> void:
	title = "个人主页"
	size = Vector2i(760, 560)
	min_size = Vector2i(680, 500)
	transient = true
	exclusive = false
	always_on_top = true

func _ready() -> void:
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]
	_build()
	EventBus.history_fragments_changed.connect(_on_growth_changed)
	EventBus.player_leveled_up.connect(_on_level_changed)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100a06")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	_tabs = TabContainer.new()
	_tabs.add_theme_font_override("font", _cn_font)
	_tabs.anchor_right = 1.0
	_tabs.anchor_bottom = 1.0
	_tabs.offset_left = 14
	_tabs.offset_top = 12
	_tabs.offset_right = -14
	_tabs.offset_bottom = -14
	add_child(_tabs)

	_attr_page = ScrollContainer.new()
	_attr_page.name = "属性"
	_tabs.add_child(_attr_page)

	_skill_page = ScrollContainer.new()
	_skill_page.name = "技能树"
	_tabs.add_child(_skill_page)

	_refresh()

func _refresh() -> void:
	_rebuild_attr_page()
	_rebuild_skill_page()

func _rebuild_attr_page() -> void:
	for c in _attr_page.get_children():
		_attr_page.remove_child(c)
		c.queue_free()
	var p = GameState.human_player()
	if p == null:
		return
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attr_page.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)

	head.add_child(_avatar_block(p))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	head.add_child(info)
	info.add_child(_label("%s · Lv.%d" % [p.display_name, p.level], 26, Color("#f5e6c8")))
	info.add_child(_label(GameState.title_for_level(p.level), 16, Color("#d4a843")))
	info.add_child(_label("历史碎片：%d / %d" % [p.history_fragments, GameState.next_level_threshold(p.level)], 14, Color("#a89a82")))
	info.add_child(_label("可用技能点：%d" % p.unspent_skill_points, 14, Color("#9bd47a")))

	var asset_row := HBoxContainer.new()
	asset_row.add_theme_constant_override("separation", 12)
	root.add_child(asset_row)
	asset_row.add_child(_stat_card("银两", "%d 两" % p.money, Color("#d4a843")))
	asset_row.add_child(_stat_card("藏品估值", "%d 两" % GameState.inventory_value(p), Color("#9bd47a")))
	asset_row.add_child(_stat_card("总资产", "%d 两" % GameState.total_assets(p), Color("#7da8d4")))
	asset_row.add_child(_stat_card("库容", "%d / %d" % [p.inventory.size(), GameState.inventory_capacity(p)], Color("#c89aff")))

	root.add_child(_label("六维属性", 18, Color("#d4a843")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for key in GameConfig.ATTRIBUTE_LABELS.keys():
		grid.add_child(_attribute_card(str(key), p))

func _rebuild_skill_page() -> void:
	for c in _skill_page.get_children():
		_skill_page.remove_child(c)
		c.queue_free()
	var p = GameState.human_player()
	if p == null:
		return
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_page.add_child(root)

	var graph := Panel.new()
	graph.custom_minimum_size = Vector2(500, 440)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = Color("#5a4630")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	graph.add_theme_stylebox_override("panel", sb)
	root.add_child(graph)

	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(220, 440)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("#1f1610")
	psb.border_color = Color("#d4a843")
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(8)
	preview.add_theme_stylebox_override("panel", psb)
	root.add_child(preview)

	var line_layer := Node2D.new()
	graph.add_child(line_layer)
	for skill in GameConfig.SKILL_TREE:
		var id := str(skill.get("id", ""))
		var pos := _skill_position(skill)
		for req in skill.get("requires", []):
			var req_def := GameState.skill_def(str(req))
			if req_def.is_empty():
				continue
			var line := Line2D.new()
			line.add_point(_skill_position(req_def) + Vector2(34, 34))
			line.add_point(pos + Vector2(34, 34))
			line.width = 4
			line.default_color = Color("#d4a843") if p.skills.get(id, false) else Color("#4d4438")
			line_layer.add_child(line)

	for track in ["鉴古线", "交易线", "收藏线"]:
		var track_lbl := _label(track, 15, Color("#d4a843"))
		track_lbl.position = Vector2(24 + _skill_track_index(track) * 150, 14)
		graph.add_child(track_lbl)
	for skill in GameConfig.SKILL_TREE:
		graph.add_child(_skill_node(skill, p, preview))
	_update_skill_preview(GameConfig.SKILL_TREE[0], p, preview)

func _skill_node(skill: Dictionary, player, preview: Panel) -> Button:
	var id := str(skill.get("id", ""))
	var unlocked: bool = player.skills.get(id, false)
	var can_unlock := GameState.can_unlock_skill(player, id)
	var btn := Button.new()
	btn.position = _skill_position(skill)
	btn.size = Vector2(68, 68)
	btn.text = _skill_icon(skill)
	btn.tooltip_text = str(skill.get("name", id))
	btn.add_theme_font_override("font", _cn_font)
	btn.add_theme_font_size_override("font_size", 24)
	var color: Color = Color("#9bd47a") if unlocked else (Color("#d4a843") if can_unlock else Color("#5b5650"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45) if not unlocked else color.darkened(0.18)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(34)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color("#f5e6c8") if unlocked or can_unlock else Color("#b0aaa0"))
	btn.pressed.connect(func(): _update_skill_preview(skill, player, preview))
	return btn

func _update_skill_preview(skill: Dictionary, player, preview: Panel) -> void:
	for c in preview.get_children():
		preview.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	preview.add_child(v)
	var id := str(skill.get("id", ""))
	var unlocked: bool = player.skills.get(id, false)
	v.add_child(_label("%s  %s" % [_skill_icon(skill), str(skill.get("name", id))], 22, Color("#f5e6c8")))
	v.add_child(_label("路线：%s · 花费：%d 点" % [str(skill.get("track", "")), int(skill.get("cost", 1))], 13, Color("#d4a843")))
	var desc := _label(str(skill.get("desc", "")), 14, Color("#a89a82"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var req_text := "无"
	if skill.get("requires", []).size() > 0:
		var names: Array[String] = []
		for req in skill.get("requires", []):
			var d := GameState.skill_def(str(req))
			names.append(str(d.get("name", req)))
		req_text = "、".join(names)
	v.add_child(_label("前置：%s" % req_text, 13, Color("#a89a82")))
	v.add_child(_label("状态：%s" % ("已点亮" if unlocked else ("可点亮" if GameState.can_unlock_skill(player, id) else "未满足")), 15, Color("#9bd47a") if unlocked else Color("#d4a843")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var btn := Button.new()
	btn.text = "已点亮" if unlocked else "点亮技能"
	btn.disabled = unlocked or not GameState.can_unlock_skill(player, id)
	btn.custom_minimum_size = Vector2(0, 38)
	btn.add_theme_font_override("font", _cn_font)
	btn.pressed.connect(func():
		if GameState.unlock_skill(GameConfig.HUMAN_PLAYER_ID, id):
			_refresh()
	)
	v.add_child(btn)

func _skill_position(skill: Dictionary) -> Vector2:
	return Vector2(28 + _skill_track_index(str(skill.get("track", ""))) * 150, 54 + _skill_depth(skill) * 86)

func _skill_track_index(track: String) -> int:
	match track:
		"鉴古线": return 0
		"交易线": return 1
		"收藏线": return 2
		_: return 0

func _skill_depth(skill: Dictionary) -> int:
	var reqs: Array = skill.get("requires", [])
	var depth := 0
	while not reqs.is_empty():
		depth += 1
		var next_def := GameState.skill_def(str(reqs[0]))
		reqs = next_def.get("requires", []) if not next_def.is_empty() else []
	return depth

func _skill_icon(skill: Dictionary) -> String:
	match str(skill.get("track", "")):
		"鉴古线": return "鉴"
		"交易线": return "商"
		"收藏线": return "藏"
		_: return "技"

func _skill_card(skill: Dictionary, player) -> Panel:
	var id := str(skill.get("id", ""))
	var unlocked: bool = player.skills.get(id, false)
	var can_unlock := GameState.can_unlock_skill(player, id)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#24301f") if unlocked else Color("#2a1f15")
	sb.border_color = Color("#9bd47a") if unlocked else Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 8
	v.offset_top = 8
	v.offset_right = -8
	v.offset_bottom = -8
	panel.add_child(v)
	v.add_child(_label("%s · %d 点" % [str(skill.get("name", id)), int(skill.get("cost", 1))], 14, Color("#f5e6c8")))
	var desc := _label(str(skill.get("desc", "")), 12, Color("#a89a82"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var btn := Button.new()
	btn.text = "已习得" if unlocked else "点亮技能"
	btn.disabled = unlocked or not can_unlock
	btn.custom_minimum_size = Vector2(0, 28)
	btn.pressed.connect(func():
		if GameState.unlock_skill(GameConfig.HUMAN_PLAYER_ID, id):
			_refresh()
	)
	v.add_child(btn)
	return panel

func _avatar_block(player) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(112, 112)
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = player.color.darkened(0.1)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(56)
	panel.add_theme_stylebox_override("panel", sb)
	var avatar := TextureRect.new()
	avatar.texture = GameConfig.get_avatar_texture(player.avatar_id, 104)
	avatar.anchor_right = 1.0
	avatar.anchor_bottom = 1.0
	avatar.offset_left = 6
	avatar.offset_top = 6
	avatar.offset_right = -6
	avatar.offset_bottom = -6
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.add_child(avatar)
	return panel

func _stat_card(key: String, value: String, color: Color) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(150, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 10
	v.offset_top = 8
	v.offset_right = -10
	v.offset_bottom = -8
	panel.add_child(v)
	v.add_child(_label(key, 12, Color("#a89a82")))
	v.add_child(_label(value, 18, color))
	return panel

func _attribute_card(key: String, player) -> Panel:
	var label: String = GameConfig.ATTRIBUTE_LABELS.get(key, key)
	var value := int(player.attributes.get(key, 0))
	var panel := _stat_card(label, str(value), Color("#f5e6c8"))
	panel.tooltip_text = _attribute_desc(key)
	return panel

func _attribute_desc(key: String) -> String:
	match key:
		"appraisal": return "缩小鉴定区间。"
		"speech": return "降低购买价格。"
		"network": return "提升高稀有资源出现率。"
		"anti_fake": return "提高识破赝品能力。"
		"fortune": return "提高游历和寺庙收益。"
		"capacity": return "增加背包库容。"
		_: return ""

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _on_growth_changed(player_id: int, _total: int, _gained: int, _reason: String) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()

func _on_level_changed(player_id: int, _level: int) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()

func _on_skill_unlocked(player_id: int, _skill_id: String) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()
