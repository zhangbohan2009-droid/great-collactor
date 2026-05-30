extends Window
## 开局抽取技能道具的提示弹窗：展示这次随机获得的道具。

var _tool_ids: Array = []
var _cn_font: SystemFont

func setup(tool_ids: Array) -> void:
	_tool_ids = tool_ids.duplicate()

func _init() -> void:
	size = Vector2i(560, 560)
	min_size = Vector2i(520, 480)
	transient = true
	exclusive = true
	always_on_top = true
	title = "技能道具入手"

func _ready() -> void:
	_cn_font = SystemFont.new()
	_cn_font.font_names = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial Unicode MS"]
	add_theme_font_override("title_font", _cn_font)
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
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	root.add_child(_center_label("技能道具入手", 22, Color("#d4a843")))
	root.add_child(_center_label("开局随机抽取，已放入你的道具栏：", 14, Color("#a89a82")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in _aggregate():
		list.add_child(_tool_card(str(entry["id"]), int(entry["count"])))

	var c := CenterContainer.new()
	root.add_child(c)
	var btn := Button.new()
	btn.text = "收下"
	btn.custom_minimum_size = Vector2(150, 38)
	btn.add_theme_font_override("font", _cn_font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func(): close_requested.emit())
	c.add_child(btn)

## 把抽到的 id 列表按出现次数聚合，保持首次出现顺序。
func _aggregate() -> Array:
	var order: Array = []
	var counts: Dictionary = {}
	for tid in _tool_ids:
		var key := str(tid)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] = int(counts[key]) + 1
	var result: Array = []
	for key in order:
		result.append({ "id": key, "count": counts[key] })
	return result

func _tool_card(tool_id: String, count: int) -> PanelContainer:
	var def := GameConfig.tool_def(tool_id)
	var tool_name := str(def.get("name", tool_id))
	var category := str(def.get("category", ""))
	var timing := str(def.get("timing", ""))
	var desc := str(def.get("desc", ""))

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f1610")
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var name_lbl := _label(tool_name, 17, Color("#f5e6c8"), false)
	head.add_child(name_lbl)
	if count > 1:
		head.add_child(_label("×%d" % count, 15, Color("#ffd166"), false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if category != "":
		head.add_child(_tag("%s · %s" % [category, timing] if timing != "" else category))

	v.add_child(_label(desc, 13, Color("#cdbf9f"), true))
	return box

func _tag(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a2e22")
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", sb)
	box.add_child(_label(text, 11, Color("#d4a843"), false))
	return box

func _center_label(text: String, size_px: int, color: Color) -> Label:
	var lbl := _label(text, size_px, color, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _label(text: String, size_px: int, color: Color, wrap: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _cn_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return lbl
