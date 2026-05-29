extends Window
## 设置：音量、返回主菜单、重新开始本局。

signal return_to_menu_requested()
signal restart_requested()

var show_game_actions := false

func _init() -> void:
	title = "设置"
	size = Vector2i(420, 360)
	min_size = Vector2i(380, 320)
	transient = true
	exclusive = false
	always_on_top = true

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#160f0a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 18
	v.offset_top = 18
	v.offset_right = -18
	v.offset_bottom = -18
	add_child(v)

	v.add_child(_label("音量设置", 24, Color("#d4a843")))
	v.add_child(_slider_row("主音量", 0))
	v.add_child(_slider_row("音乐", 1))
	v.add_child(_slider_row("音效", 2))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	if show_game_actions:
		var restart := _btn("重新开始本局", Color("#e7b34a"))
		restart.pressed.connect(func(): restart_requested.emit())
		v.add_child(restart)
		var menu := _btn("保存并返回主菜单", Color("#7da8d4"))
		menu.pressed.connect(func(): return_to_menu_requested.emit())
		v.add_child(menu)

	var close_btn := _btn("关闭", Color("#7d6a4a"))
	close_btn.pressed.connect(func(): emit_signal("close_requested"))
	v.add_child(close_btn)

func _slider_row(text: String, bus_idx: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _label(text, 15, Color("#f5e6c8"))
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(min(bus_idx, AudioServer.bus_count - 1)))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v):
		var idx: int = min(bus_idx, AudioServer.bus_count - 1)
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(0.001, float(v))))
	)
	row.add_child(slider)
	return row

func _label(text: String, size_px: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.45)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", Color("#f5e6c8"))
	return b
