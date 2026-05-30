extends Window
## 购入 / 售出后的结算弹窗。

var _mode := "purchase"
var _inst: Resource = null
var _before_fragments := 0
var _after_fragments := 0
var _before_level := 1
var _after_level := 1
var _sale_price := 0
var _paid_price := 0
var _cn_font: SystemFont
var _coin_texture: Texture2D

func setup_purchase(inst: Resource, before_fragments: int, before_level: int, after_fragments: int, after_level: int) -> void:
	_mode = "purchase"
	_inst = inst
	_before_fragments = before_fragments
	_after_fragments = after_fragments
	_before_level = before_level
	_after_level = after_level
	title = "文物入藏"

func setup_sale(inst: Resource, sale_price: int, paid_price: int) -> void:
	_mode = "sale"
	_inst = inst
	_sale_price = sale_price
	_paid_price = paid_price
	title = "交易结算"

func _init() -> void:
	size = Vector2i(560, 500)
	min_size = Vector2i(500, 420)
	transient = true
	exclusive = true
	always_on_top = true

func _ready() -> void:
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]
	_coin_texture = _make_coin_texture(32)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#160f0a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = -18
	panel.offset_bottom = -18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15")
	sb.border_color = _inst.rarity_color() if _inst != null else Color("#d4a843")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	root.add_child(_title_label("文物入藏" if _mode == "purchase" else "交易结算"))
	if _inst != null:
		var icon_center := CenterContainer.new()
		icon_center.add_child(_relic_icon(_inst))
		root.add_child(icon_center)
		root.add_child(_center_label(_inst.display_name(), 24, Color("#f5e6c8")))
		root.add_child(_center_label("%s · %s · %s" % [_inst.def.country, _inst.def.rarity_label(), _inst.def.type_icon()], 14, _inst.rarity_color()))

	if _mode == "purchase":
		_add_purchase_lines(root)
	else:
		_add_sale_lines(root)

	var story_text: String = str(_inst.def.story) if _inst != null and _inst.def != null else ""
	if story_text != "":
		var story := _label(story_text, 13, Color("#a89a82"))
		story.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(story)

	var c := CenterContainer.new()
	root.add_child(c)
	var btn := Button.new()
	btn.text = "知道了"
	btn.custom_minimum_size = Vector2(150, 38)
	btn.add_theme_font_override("font", _cn_font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func(): close_requested.emit())
	c.add_child(btn)

func _add_purchase_lines(root: VBoxContainer) -> void:
	if _inst == null:
		return
	root.add_child(_money_row("购入", _inst.paid_price, Color("#d4a843"), "两"))
	root.add_child(_money_row("估值约", int(_inst.estimated_value), Color("#ffd166"), "两 · %s" % ("赝品" if _inst.is_fake else "真品")))
	var gained: int = _after_fragments - _before_fragments
	var level_text := "等级 Lv.%d" % _after_level
	if _after_level > _before_level:
		level_text = "等级 Lv.%d -> Lv.%d" % [_before_level, _after_level]
	root.add_child(_center_label("经验 +%d（%d -> %d） · %s" % [gained, _before_fragments, _after_fragments, level_text], 14, Color("#9bd47a")))

func _add_sale_lines(root: VBoxContainer) -> void:
	var net: int = _sale_price - _paid_price
	var rate: float = 0.0
	if _paid_price > 0:
		rate = float(net) / float(_paid_price) * 100.0
	var sign := "+" if net >= 0 else ""
	var rate_sign := "+" if rate >= 0.0 else ""
	var color := Color("#9bd47a") if net >= 0 else Color("#d47a7a")
	root.add_child(_money_row("售价", _sale_price, Color("#ffd166"), "两"))
	root.add_child(_money_row("成本", _paid_price, Color("#d4a843"), "两"))
	root.add_child(_money_row("净赚", net, color, "两（%s%.1f%%）" % [rate_sign, rate], sign))

func _money_row(label_text: String, amount: int, color: Color, suffix: String = "两", sign: String = "") -> CenterContainer:
	var center := CenterContainer.new()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	center.add_child(row)

	var label := _label("%s：" % label_text, 14, Color("#d8c6a3"))
	row.add_child(label)
	row.add_child(_coin_icon(22))
	var amount_lbl := _label("%s%d" % [sign, amount], 18, color)
	amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	amount_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(amount_lbl)
	row.add_child(_label(suffix, 14, Color("#d4a843")))
	return center

func _coin_icon(size_px: int) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = _coin_texture
	coin.custom_minimum_size = Vector2(size_px, size_px)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return coin

func _make_coin_texture(size_px: int) -> Texture2D:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(size_px - 1) * 0.5, float(size_px - 1) * 0.5)
	var radius := float(size_px) * 0.42
	for y in range(size_px):
		for x in range(size_px):
			var p := Vector2(float(x), float(y))
			var dist := p.distance_to(center)
			if dist > radius:
				continue
			var t := clampf(dist / radius, 0.0, 1.0)
			var color := Color("#f6c453").lerp(Color("#b66a1c"), t)
			if dist > radius * 0.82:
				color = Color("#7a3f12")
			elif dist < radius * 0.38:
				color = color.lightened(0.24)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _relic_icon(inst: Resource) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(88, 112)
	var sb := StyleBoxFlat.new()
	sb.bg_color = inst.rarity_color().darkened(0.35)
	sb.border_color = Color("#1f1610")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _center_label(inst.type_icon(), 34, Color("#f5e6c8"))
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _title_label(text: String) -> Label:
	return _center_label(text, 22, Color("#d4a843"))

func _center_label(text: String, size_px: int, color: Color) -> Label:
	var lbl := _label(text, size_px, color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
