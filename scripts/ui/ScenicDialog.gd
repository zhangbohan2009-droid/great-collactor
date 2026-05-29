extends Window
## 景点占位弹窗：路过得到一点情报（MVP：仅一个 离开 按钮）

var _tile = null
var _intro_cb: Callable

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
	title = "景点"
	size = Vector2i(420, 240)
	min_size = Vector2i(380, 200)
	transient = true
	exclusive = true
	always_on_top = true

func setup(tile) -> void:
	_tile = tile
	title = "景点 · %s" % tile.display_name

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#16221a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 20
	v.offset_top = 20
	v.offset_right = -20
	v.offset_bottom = -20
	add_child(v)

	var head := Label.new()
	head.text = "你途经 %s" % _tile.display_name
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color("#9bd47a"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)

	var body := Label.new()
	body.text = "（MVP 占位）此处后续将开放：NPC 相遇、历史碎片、隐藏成就。"
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color("#a89a82"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)

	var c := CenterContainer.new()
	v.add_child(c)
	var btn := Button.new()
	btn.text = "继 续 前 行"
	btn.custom_minimum_size = Vector2(160, 36)
	btn.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#4a8060").darkened(0.4)
	sb.border_color = Color("#4a8060")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("#f5e6c8"))
	btn.pressed.connect(func(): emit_signal("close_requested"))
	c.add_child(btn)
