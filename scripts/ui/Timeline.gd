extends Control
## 右下纵向时间轴：滚动窗口，展示当前回合及未来 4 个回合。
## 回合推进时整列向上滚动（转动动效），最底部用渐变遮罩淡出，暗示后面还有回合。
## 当前回合高亮，拍卖回合标“拍”（旅途模式无拍卖、无回合上限）。

const VISIBLE_ROUNDS: int = 4
const CELL_H: int = 24
const CELL_SEP: int = 3
const STEP: int = CELL_H + CELL_SEP
const PEEK: int = 14            # 第 5 张卡露出的高度，被渐变淡出
const MARGIN_Y: int = 5
const COUNTER_H: int = 26       # 底部回合计数块高度
const COUNTER_GAP: int = 4
const VIEW_H: int = VISIBLE_ROUNDS * STEP + PEEK
const BOX_H: int = MARGIN_Y * 2 + VIEW_H + COUNTER_GAP + COUNTER_H
const FADE_COLOR := Color(0.05, 0.035, 0.02)

var _cells: Array = []
var _reel: VBoxContainer
var _viewport: Control
var _counter_label: Label
var _displayed_start: int = -9999
var _tween: Tween

func _init() -> void:
	custom_minimum_size = Vector2(46, BOX_H)

func _ready() -> void:
	_build()
	_apply_window(false)
	EventBus.round_started.connect(func(_n): _apply_window(true))
	EventBus.phase_changed.connect(func(_p): _apply_window(false))

func _build() -> void:
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(FADE_COLOR, 0.55)
	sb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.anchor_right = 1.0
	_viewport.anchor_bottom = 1.0
	_viewport.offset_left = 7
	_viewport.offset_top = MARGIN_Y
	_viewport.offset_right = -7
	_viewport.offset_bottom = -(MARGIN_Y + COUNTER_H + COUNTER_GAP)
	_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport)

	_reel = VBoxContainer.new()
	_reel.add_theme_constant_override("separation", CELL_SEP)
	_reel.position = Vector2(0, 0)
	_reel.anchor_right = 1.0
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_reel)

	# 多建一张作为滚动缓冲（露在底部被淡出）。
	for i in range(VISIBLE_ROUNDS + 1):
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(30, CELL_H)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(lbl)
		_reel.add_child(cell)
		_cells.append(cell)

	_add_fade_overlay()
	_add_counter_block()

func _add_counter_block() -> void:
	var box := Panel.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 7
	box.offset_right = -7
	box.offset_top = -(MARGIN_Y + COUNTER_H)
	box.offset_bottom = -MARGIN_Y
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#d4a843").darkened(0.45)
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", sb)
	add_child(box)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 13)
	_counter_label.add_theme_color_override("font_color", Color("#f5e6c8"))
	_counter_label.anchor_right = 1.0
	_counter_label.anchor_bottom = 1.0
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_counter_label)
	_refresh_counter()

func _refresh_counter() -> void:
	if _counter_label == null:
		return
	var cur: int = max(0, GameState.current_round)
	if GameState.is_journey_mode():
		_counter_label.text = "%d / ∞" % cur
	else:
		_counter_label.text = "%d / %d" % [cur, GameConfig.MAX_ROUNDS]

func _add_fade_overlay() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(FADE_COLOR, 0.0))
	grad.set_color(1, Color(FADE_COLOR, 1.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 64
	var fade := TextureRect.new()
	fade.texture = tex
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_left = 0.0
	fade.anchor_right = 1.0
	fade.anchor_top = 1.0
	fade.anchor_bottom = 1.0
	fade.offset_top = -(PEEK + STEP)
	_viewport.add_child(fade)

func _window_start() -> int:
	var cur: int = max(1, GameState.current_round)
	if GameState.is_journey_mode():
		return cur
	# 普通模式：窗口不越过 MAX_ROUNDS，临近结束时锁定到最后一屏。
	var max_start: int = max(1, GameConfig.MAX_ROUNDS - VISIBLE_ROUNDS + 1)
	return clampi(cur, 1, max_start)

func _apply_window(animate: bool) -> void:
	_refresh_counter()
	var new_start := _window_start()
	if animate and new_start == _displayed_start + 1:
		_animate_scroll(new_start)
	else:
		if _tween and _tween.is_running():
			_tween.kill()
		_displayed_start = new_start
		_reel.position.y = 0
		_populate(new_start)

func _animate_scroll(new_start: int) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	# 先在旧窗口上刷新高亮（当前回合下移一格的视觉起点），再整列上滚一格。
	_populate(_displayed_start)
	_reel.position.y = 0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_reel, "position:y", float(-STEP), 0.34)
	_tween.tween_callback(func():
		_displayed_start = new_start
		_reel.position.y = 0
		_populate(new_start)
	)

func _populate(start: int) -> void:
	var journey := GameState.is_journey_mode()
	for i in range(_cells.size()):
		var cell: Panel = _cells[i]
		var round_num := start + i
		var lbl: Label = cell.get_child(0)
		var visible_cell := journey or round_num <= GameConfig.MAX_ROUNDS
		cell.visible = visible_cell
		if not visible_cell:
			continue
		var is_auction := (not journey) and GameConfig.AUCTION_ROUNDS.has(round_num)
		lbl.text = "拍" if is_auction else str(round_num)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if round_num == GameState.current_round:
			sb.bg_color = Color("#d4a843")
		elif is_auction:
			sb.bg_color = Color("#b03020").darkened(0.2)
		else:
			sb.bg_color = Color("#3a2e22")
		cell.add_theme_stylebox_override("panel", sb)
