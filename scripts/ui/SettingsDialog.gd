extends Window
## 设置：音量、返回主菜单、重新开始本局。

signal return_to_menu_requested()
signal restart_requested()

var show_game_actions := false
var _fullscreen_check: CheckBox
var _resolution_buttons: Array = []
var _resolution_note: Label

func _init() -> void:
	title = "设置"
	size = Vector2i(520, 560)
	min_size = Vector2i(460, 500)
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
	v.add_child(HSeparator.new())
	v.add_child(_label("显示设置", 24, Color("#d4a843")))
	v.add_child(_fullscreen_row())
	v.add_child(_resolution_row())
	_resolution_note = _label("分辨率在窗口模式下生效；全屏会使用当前显示器分辨率。", 12, Color("#a89a82"))
	v.add_child(_resolution_note)

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

func _fullscreen_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _label("窗口模式", 15, Color("#f5e6c8"))
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "全屏"
	_fullscreen_check.button_pressed = UserSettings.fullscreen
	_fullscreen_check.add_theme_font_size_override("font_size", 15)
	_fullscreen_check.add_theme_color_override("font_color", Color("#f5e6c8"))
	_fullscreen_check.toggled.connect(func(pressed: bool):
		UserSettings.set_fullscreen(pressed)
		_refresh_resolution_buttons()
	)
	row.add_child(_fullscreen_check)
	return row

func _resolution_row() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var label := _label("分辨率", 15, Color("#f5e6c8"))
	root.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	_resolution_buttons.clear()
	for res in UserSettings.RESOLUTIONS:
		var resolution: Vector2i = res
		var btn := _resolution_btn(resolution)
		btn.pressed.connect(_on_resolution_pressed.bind(resolution))
		grid.add_child(btn)
		_resolution_buttons.append({ "button": btn, "resolution": resolution })
	_refresh_resolution_buttons()
	return root

func _on_resolution_pressed(resolution: Vector2i) -> void:
	UserSettings.set_resolution(resolution)
	_refresh_resolution_buttons()

func _resolution_btn(resolution: Vector2i) -> Button:
	var btn := Button.new()
	btn.text = UserSettings.resolution_label(resolution)
	btn.custom_minimum_size = Vector2(140, 40)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _refresh_resolution_buttons() -> void:
	for entry in _resolution_buttons:
		var btn: Button = entry["button"]
		var resolution: Vector2i = entry["resolution"]
		var selected := UserSettings.is_current_resolution(resolution)
		btn.disabled = UserSettings.fullscreen
		btn.add_theme_stylebox_override("normal", _resolution_style(selected, UserSettings.fullscreen))
		btn.add_theme_stylebox_override("hover", _resolution_style(true, UserSettings.fullscreen))
		btn.add_theme_stylebox_override("pressed", _resolution_style(true, UserSettings.fullscreen))
		btn.add_theme_color_override("font_color", Color("#f5e6c8") if selected else Color("#c9b99d"))
		btn.add_theme_color_override("font_disabled_color", Color("#7d6a4a"))
	if _resolution_note != null:
		_resolution_note.text = "当前为全屏模式，分辨率选择会保留但暂不改变显示器分辨率。" if UserSettings.fullscreen else "分辨率在窗口模式下立即生效。"

func _resolution_style(selected: bool, disabled: bool) -> StyleBoxFlat:
	var color := Color("#d4a843") if selected else Color("#7da8d4")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15") if not disabled else Color("#1c1712")
	if selected and not disabled:
		sb.bg_color = color.darkened(0.35)
	sb.border_color = color if not disabled else Color("#4d4438")
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(8)
	return sb

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
