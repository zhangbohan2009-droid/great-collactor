extends Control
## 单人模式开局配置：名称、头像、初始技能点。

signal start_requested(profile: Dictionary)
signal back_requested()

var _name_edit: LineEdit
var _selected_avatar := "collector_gold"
var _selected_color := Color("#d4a843")
var _selected_skill := ""

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#160f0a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760, 660)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("#24180f")
	psb.border_color = Color("#d4a843")
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	panel.add_child(root)

	root.add_child(_label("创建藏家", 36, Color("#d4a843")))
	root.add_child(_label("设置本局身份。初始技能点为 1 点，可先点亮一个入门技能。", 15, Color("#a89a82")))

	_name_edit = LineEdit.new()
	_name_edit.text = "大收藏家"
	_name_edit.placeholder_text = "输入名称"
	_name_edit.custom_minimum_size = Vector2(0, 44)
	root.add_child(_name_edit)

	root.add_child(_label("选择头像", 18, Color("#f5e6c8")))
	var avatars := HBoxContainer.new()
	avatars.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars.add_theme_constant_override("separation", 14)
	root.add_child(avatars)
	avatars.add_child(_avatar_btn("collector_gold", "金牌藏家", Color("#d4a843")))
	avatars.add_child(_avatar_btn("jade_green", "玉器行家", Color("#4a8060")))
	avatars.add_child(_avatar_btn("ink_blue", "掌眼先生", Color("#3a78a8")))
	avatars.add_child(_avatar_btn("market_red", "市井掌柜", Color("#b03020")))

	root.add_child(_label("初始技能", 18, Color("#f5e6c8")))
	var skills := GridContainer.new()
	skills.columns = 3
	skills.add_theme_constant_override("h_separation", 10)
	skills.add_theme_constant_override("v_separation", 10)
	root.add_child(skills)
	for skill in GameConfig.SKILL_TREE:
		if skill.get("requires", []).is_empty():
			skills.add_child(_skill_btn(skill))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	var back := _btn("返回", Color("#7d6a4a"))
	back.pressed.connect(func(): back_requested.emit())
	row.add_child(back)
	var start := _btn("开始本局", Color("#d4a843"))
	start.pressed.connect(_on_start)
	row.add_child(start)

func _avatar_btn(id: String, text: String, color: Color) -> Button:
	var b := _btn("", color)
	b.custom_minimum_size = Vector2(96, 84)
	b.tooltip_text = text
	b.icon = load(str(GameConfig.AVATAR_TEXTURES.get(id, "")))
	b.expand_icon = true
	b.toggle_mode = true
	b.button_pressed = id == _selected_avatar
	b.pressed.connect(func():
		_selected_avatar = id
		_selected_color = color
	)
	return b

func _skill_btn(skill: Dictionary) -> Button:
	var id := str(skill.get("id", ""))
	var b := _btn("%s\n%s" % [str(skill.get("name", id)), str(skill.get("desc", ""))], Color("#7da8d4"))
	b.custom_minimum_size = Vector2(220, 76)
	b.toggle_mode = true
	b.pressed.connect(func():
		_selected_skill = id if b.button_pressed else ""
	)
	return b

func _on_start() -> void:
	start_requested.emit({
		"name": _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "大收藏家",
		"avatar_id": _selected_avatar,
		"color": _selected_color,
		"skill_points": 1,
		"initial_skill": _selected_skill,
	})

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.25)
	var pressed := sb.duplicate()
	pressed.bg_color = color.darkened(0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	return b
