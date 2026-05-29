extends Control
## 主菜单：新游戏 / 继续游戏 / 设置 / 退出

signal new_game_requested()
signal continue_requested()
signal settings_requested()
signal quit_requested()

const RPG_UI := "res://assets/ui/kenney_rpg/PNG/"
const PANEL_BROWN := RPG_UI + "panel_brown.png"
const PANEL_INSET_BROWN := RPG_UI + "panelInset_brown.png"
const BTN_BEIGE := RPG_UI + "buttonLong_beige.png"
const BTN_BEIGE_PRESSED := RPG_UI + "buttonLong_beige_pressed.png"
const BTN_BLUE_RPG := RPG_UI + "buttonLong_blue.png"
const BTN_BLUE_RPG_PRESSED := RPG_UI + "buttonLong_blue_pressed.png"
const BTN_BROWN := RPG_UI + "buttonLong_brown.png"
const BTN_BROWN_PRESSED := RPG_UI + "buttonLong_brown_pressed.png"
const BTN_GREY_RPG := RPG_UI + "buttonLong_grey.png"
const BTN_GREY_RPG_PRESSED := RPG_UI + "buttonLong_grey_pressed.png"
const ICON_CIRCLE_BEIGE := RPG_UI + "iconCircle_beige.png"
const ARROW_BROWN_LEFT := RPG_UI + "arrowBrown_left.png"
const ARROW_BROWN_RIGHT := RPG_UI + "arrowBrown_right.png"

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#17100c")
	_fill_parent(bg)
	add_child(bg)

	var warm_glow := ColorRect.new()
	warm_glow.color = Color(0.58, 0.33, 0.12, 0.14)
	warm_glow.anchor_left = 0.1
	warm_glow.anchor_top = 0.08
	warm_glow.anchor_right = 0.9
	warm_glow.anchor_bottom = 0.92
	add_child(warm_glow)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.015, 0.38)
	_fill_parent(shade)
	shade.offset_left = 64
	shade.offset_top = 64
	shade.offset_right = -64
	shade.offset_bottom = -64
	add_child(shade)

	var center := CenterContainer.new()
	_fill_parent(center)
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(600, 710)
	frame.add_theme_stylebox_override("panel", _make_texture_style(PANEL_BROWN, 28, 32))
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	frame.add_child(box)

	var crest := HBoxContainer.new()
	crest.alignment = BoxContainer.ALIGNMENT_CENTER
	crest.add_theme_constant_override("separation", 12)
	box.add_child(crest)

	crest.add_child(_make_icon(ARROW_BROWN_LEFT, Vector2(42, 42)))
	crest.add_child(_make_icon(ICON_CIRCLE_BEIGE, Vector2(34, 34)))
	crest.add_child(_make_icon(ARROW_BROWN_RIGHT, Vector2(42, 42)))

	var title := Label.new()
	title.text = "大 收 藏 家"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("#ffe6a8"))
	title.add_theme_color_override("font_shadow_color", Color(0.16, 0.08, 0.03, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "多人大富翁式 · 古董交易 MVP"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("#ead5ae"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", Color("#8f5a2b"))
	box.add_child(rule)

	var btn_new := _make_btn("新 游 戏", Color("#d4a843"), BTN_BEIGE, BTN_BEIGE_PRESSED)
	btn_new.pressed.connect(func(): new_game_requested.emit())
	box.add_child(btn_new)

	var btn_continue := _make_btn("继 续 游 戏", Color("#9bd47a"), BTN_BROWN, BTN_BROWN_PRESSED)
	btn_continue.disabled = not SaveSystem.has_save()
	btn_continue.tooltip_text = "没有存档" if btn_continue.disabled else "读取当前存档"
	btn_continue.pressed.connect(func(): continue_requested.emit())
	box.add_child(btn_continue)

	var btn_settings := _make_btn("设 置", Color("#7da8d4"), BTN_BLUE_RPG, BTN_BLUE_RPG_PRESSED)
	btn_settings.pressed.connect(func(): settings_requested.emit())
	box.add_child(btn_settings)

	var btn_quit := _make_btn("退 出", Color("#7d6a4a"), BTN_GREY_RPG, BTN_GREY_RPG_PRESSED)
	btn_quit.pressed.connect(func(): quit_requested.emit())
	box.add_child(btn_quit)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	box.add_child(chips)
	chips.add_child(_make_chip("1 真人"))
	chips.add_child(_make_chip("2 AI"))
	chips.add_child(_make_chip("12 回合"))

	var hint := Label.new()
	hint.text = "第 4 / 8 / 12 回合开启拍卖，收藏、交易并冲击最终资产排名"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#f0d7ad"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_stylebox_override("normal", _make_texture_style(PANEL_INSET_BROWN, 14, 14))
	box.add_child(hint)

func _make_btn(text: String, color: Color, texture_path: String = "", pressed_texture_path: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 66)
	b.add_theme_font_size_override("font_size", 22)
	var normal: StyleBox
	var hover: StyleBox
	var pressed: StyleBox
	var tex = load(texture_path) if texture_path != "" else null
	if tex != null:
		var n := StyleBoxTexture.new()
		n.texture = tex
		n.set_texture_margin_all(12)
		n.set_content_margin_all(10)
		normal = n
		hover = n.duplicate()
		hover.modulate_color = Color(1.12, 1.08, 0.96, 1.0)
		var pressed_tex = load(pressed_texture_path) if pressed_texture_path != "" else tex
		var p := StyleBoxTexture.new()
		p.texture = pressed_tex
		p.set_texture_margin_all(12)
		p.set_content_margin_all(10)
		pressed = p
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = color.darkened(0.4)
		flat.border_color = color
		flat.set_border_width_all(2)
		flat.set_corner_radius_all(6)
		flat.set_content_margin_all(8)
		normal = flat
		var h := flat.duplicate()
		h.bg_color = color.darkened(0.2)
		hover = h
		var p := flat.duplicate()
		p.bg_color = color.darkened(0.6)
		pressed = p
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", _make_texture_style(BTN_GREY_RPG, 12, 10))
	b.add_theme_color_override("font_color", Color("#3b2414"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("#2b1a10"))
	b.add_theme_color_override("font_disabled_color", Color("#766d60"))
	return b

func _make_texture_style(texture_path: String, texture_margin: int, content_margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path)
	style.set_texture_margin_all(texture_margin)
	style.set_content_margin_all(content_margin)
	return style

func _make_icon(texture_path: String, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(texture_path)
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func _make_chip(text: String) -> Label:
	var chip := Label.new()
	chip.text = text
	chip.custom_minimum_size = Vector2(112, 36)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", Color("#f4dfb9"))
	chip.add_theme_stylebox_override("normal", _make_texture_style(PANEL_INSET_BROWN, 12, 8))
	return chip

func _fill_parent(node: Control) -> void:
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
