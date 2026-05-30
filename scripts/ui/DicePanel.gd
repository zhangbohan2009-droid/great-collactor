extends Control
## 右下骰子面板：当前阶段 + 骰子值 + 掷骰按钮。

var _dice_label: Label
var _hint_label: Label
var _dice_button: Button
var _tool_box: VBoxContainer
var _fixed_row: HBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(182, 328)

func _ready() -> void:
	_build()
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.player_ready_changed.connect(_on_ready_changed)
	_refresh()

func _build() -> void:
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.78)
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	bg.add_theme_stylebox_override("panel", sb)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", 8)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	add_child(v)

	_hint_label = Label.new()
	_hint_label.text = "等待开局"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color("#a89a82"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint_label)

	_dice_button = Button.new()
	_dice_button.text = ""
	_dice_button.custom_minimum_size = Vector2(120, 120)
	_dice_button.focus_mode = Control.FOCUS_NONE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("#f5e6c8")
	dsb.border_color = Color("#1f1610")
	dsb.set_border_width_all(3)
	dsb.set_corner_radius_all(14)
	var hover_dsb := dsb.duplicate()
	hover_dsb.bg_color = Color("#fff1d4")
	var pressed_dsb := dsb.duplicate()
	pressed_dsb.bg_color = Color("#d4a843")
	var disabled_dsb := dsb.duplicate()
	disabled_dsb.bg_color = Color("#8a7a62")
	disabled_dsb.border_color = Color("#3a3028")
	_dice_button.add_theme_stylebox_override("normal", dsb)
	_dice_button.add_theme_stylebox_override("hover", hover_dsb)
	_dice_button.add_theme_stylebox_override("pressed", pressed_dsb)
	_dice_button.add_theme_stylebox_override("disabled", disabled_dsb)
	_dice_button.pressed.connect(_on_roll_pressed)

	_dice_label = Label.new()
	_dice_label.text = "—"
	_dice_label.add_theme_font_size_override("font_size", 52)
	_dice_label.add_theme_color_override("font_color", Color("#1f1610"))
	_dice_label.anchor_right = 1.0
	_dice_label.anchor_bottom = 1.0
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_button.add_child(_dice_label)

	var dice_center := CenterContainer.new()
	dice_center.add_child(_dice_button)
	v.add_child(dice_center)

	_tool_box = VBoxContainer.new()
	_tool_box.add_theme_constant_override("separation", 4)
	v.add_child(_tool_box)

	_fixed_row = HBoxContainer.new()
	_fixed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_fixed_row.add_theme_constant_override("separation", 2)
	v.add_child(_fixed_row)

func _refresh() -> void:
	var phase: String = GameState.current_phase
	var human = GameState.human_player()
	_dice_button.disabled = true
	_refresh_tool_buttons()
	match phase:
		"dice":
			if human != null and not human.ready:
				_hint_label.text = "你的回合：掷骰"
				_dice_button.disabled = false
				_dice_label.text = "?"
			else:
				_hint_label.text = "等待其他玩家掷骰…"
		"move":
			_hint_label.text = "移动中…"
		"event":
			_hint_label.text = "处理事件…"
		"auction":
			_hint_label.text = "拍卖中…"
		"ranking":
			_hint_label.text = "结算"
		"round_begin":
			_hint_label.text = "新回合"
		"round_end":
			_hint_label.text = "回合结束"
		_:
			_hint_label.text = "—"

func _on_roll_pressed() -> void:
	_dice_button.disabled = true
	GameFlow.roll_dice_for(GameConfig.HUMAN_PLAYER_ID)

func _refresh_tool_buttons() -> void:
	if _tool_box == null or _fixed_row == null:
		return
	for child in _tool_box.get_children():
		child.queue_free()
	for child in _fixed_row.get_children():
		child.queue_free()
	var human = GameState.human_player()
	if human == null:
		return
	var move_tools := ["reverse_card", "small_step_card", "double_step_card", "fixed_dice_card"]
	for tool_id in move_tools:
		var count := GameState.tool_count(GameConfig.HUMAN_PLAYER_ID, tool_id)
		if count <= 0:
			continue
		var btn := Button.new()
		btn.text = "%s x%d" % [GameConfig.tool_name(tool_id), count]
		btn.custom_minimum_size = Vector2(156, 26)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = not GameFlow.can_use_dice_tool(GameConfig.HUMAN_PLAYER_ID, tool_id)
		btn.tooltip_text = str(GameConfig.tool_def(tool_id).get("desc", ""))
		_apply_tool_button_style(btn, tool_id)
		if tool_id == "fixed_dice_card":
			btn.pressed.connect(_show_fixed_dice_choices)
		else:
			btn.pressed.connect(func(t: String = tool_id):
				if GameFlow.use_dice_tool(GameConfig.HUMAN_PLAYER_ID, t):
					_refresh()
			)
		_tool_box.add_child(btn)

func _show_fixed_dice_choices() -> void:
	for child in _fixed_row.get_children():
		child.queue_free()
	if not GameFlow.can_use_dice_tool(GameConfig.HUMAN_PLAYER_ID, "fixed_dice_card"):
		return
	for value in range(GameConfig.DICE_MIN, GameConfig.DICE_MAX + 1):
		var btn := Button.new()
		btn.text = str(value)
		btn.custom_minimum_size = Vector2(26, 24)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(v := value):
			if GameFlow.use_dice_tool(GameConfig.HUMAN_PLAYER_ID, "fixed_dice_card", { "value": v }):
				_dice_label.text = str(v)
				_refresh()
		)
		_fixed_row.add_child(btn)

func _apply_tool_button_style(btn: Button, tool_id: String) -> void:
	var color := Color("#7da8d4")
	match tool_id:
		"fixed_dice_card":
			color = Color("#d4a843")
		"reverse_card":
			color = Color("#c89aff")
		"small_step_card":
			color = Color("#9bd47a")
		"double_step_card":
			color = Color("#d4843a")
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.48)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.28)
	var disabled := sb.duplicate()
	disabled.bg_color = Color("#3a3028")
	disabled.border_color = Color("#5a5148")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color("#f5e6c8"))

func _on_phase_changed(_phase: String) -> void:
	_refresh()

func _on_dice_rolled(player_id: int, value: int) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_dice_label.text = str(value)

func _on_ready_changed(_id: int, _ready: bool, _phase: String) -> void:
	_refresh()

