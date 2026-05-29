extends Control
## 右下骰子面板：当前阶段 + 骰子值 + 掷骰按钮。

var _dice_label: Label
var _hint_label: Label
var _roll_btn: Button

func _init() -> void:
	custom_minimum_size = Vector2(154, 194)

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
	v.alignment = BoxContainer.ALIGNMENT_CENTER
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

	# 骰子方块
	var dice_box := Panel.new()
	dice_box.custom_minimum_size = Vector2(66, 66)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("#f5e6c8")
	dsb.border_color = Color("#1f1610")
	dsb.set_border_width_all(3)
	dsb.set_corner_radius_all(8)
	dice_box.add_theme_stylebox_override("panel", dsb)

	_dice_label = Label.new()
	_dice_label.text = "—"
	_dice_label.add_theme_font_size_override("font_size", 34)
	_dice_label.add_theme_color_override("font_color", Color("#1f1610"))
	_dice_label.anchor_right = 1.0
	_dice_label.anchor_bottom = 1.0
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_box.add_child(_dice_label)

	var dice_center := CenterContainer.new()
	dice_center.add_child(dice_box)
	v.add_child(dice_center)

	_roll_btn = Button.new()
	_roll_btn.text = "掷骰"
	_roll_btn.custom_minimum_size = Vector2(112, 36)
	_roll_btn.add_theme_font_size_override("font_size", 16)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#d4a843").darkened(0.4)
	bsb.border_color = Color("#d4a843")
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(6)
	_roll_btn.add_theme_stylebox_override("normal", bsb)
	_roll_btn.add_theme_color_override("font_color", Color("#f5e6c8"))
	_roll_btn.pressed.connect(_on_roll_pressed)
	var roll_center := CenterContainer.new()
	roll_center.add_child(_roll_btn)
	v.add_child(roll_center)

func _refresh() -> void:
	var phase: String = GameState.current_phase
	var human = GameState.human_player()
	_roll_btn.disabled = true
	match phase:
		"dice":
			if human != null and not human.ready:
				_hint_label.text = "你的回合：掷骰"
				_roll_btn.disabled = false
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
	_roll_btn.disabled = true
	GameFlow.roll_dice_for(GameConfig.HUMAN_PLAYER_ID)

func _on_phase_changed(_phase: String) -> void:
	_refresh()

func _on_dice_rolled(player_id: int, value: int) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_dice_label.text = str(value)

func _on_ready_changed(_id: int, _ready: bool, _phase: String) -> void:
	_refresh()

