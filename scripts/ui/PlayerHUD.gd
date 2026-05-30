extends Control
## 左上身份卡：头像、名称、等级、历史碎片、银两、藏品估值。

const CoinIcon := preload("res://scripts/ui/CoinIcon.gd")

var _money_label: Label
var _inv_label: Label
var _name_label: Label
var _level_label: Label
var _fragments_label: Label
var _progress: ProgressBar
var _avatar: Panel

func _init() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	custom_minimum_size = Vector2(330, 132)
	size = Vector2(330, 132)
	position = Vector2(16, 14)

func _ready() -> void:
	_build()
	_refresh()
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.round_started.connect(_on_round_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.history_fragments_changed.connect(_on_history_changed)
	EventBus.player_leveled_up.connect(_on_level_changed)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)

func _build() -> void:
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.76)
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	bg.add_theme_stylebox_override("panel", sb)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 12
	row.offset_top = 12
	row.offset_right = -12
	row.offset_bottom = -12
	add_child(row)

	_avatar = Panel.new()
	_avatar.custom_minimum_size = Vector2(76, 76)
	row.add_child(_avatar)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	row.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color("#f5e6c8"))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", Color("#d4a843"))
	head.add_child(_level_label)

	_fragments_label = Label.new()
	_fragments_label.add_theme_font_size_override("font_size", 12)
	_fragments_label.add_theme_color_override("font_color", Color("#a89a82"))
	col.add_child(_fragments_label)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 12)
	_progress.show_percentage = false
	col.add_child(_progress)

	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 14)
	col.add_child(nums)
	nums.add_child(_make_money_box())
	_inv_label = _make_kv("藏品", "0/0 · 0 两")
	nums.add_child(_inv_label)

func _make_money_box() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(CoinIcon.make_icon(18))
	_money_label = Label.new()
	_money_label.text = "0"
	_money_label.add_theme_font_size_override("font_size", 13)
	_money_label.add_theme_color_override("font_color", Color("#f5e6c8"))
	box.add_child(_money_label)
	return box

func _make_kv(key: String, value: String) -> Label:
	var lbl := Label.new()
	lbl.text = "%s %s" % [key, value]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	lbl.set_meta("key", key)
	return lbl

func _set_kv(lbl: Label, value: String) -> void:
	var key: String = lbl.get_meta("key", "")
	lbl.text = "%s  %s" % [key, value]

func _refresh() -> void:
	var p = GameState.human_player()
	if p == null:
		return
	_apply_avatar(p)
	var current_threshold := GameState.current_level_threshold(p.level)
	var next_threshold := GameState.next_level_threshold(p.level)
	_name_label.text = p.display_name
	_level_label.text = "Lv.%d · %s" % [p.level, GameState.title_for_level(p.level)]
	if p.level >= 10:
		_fragments_label.text = "历史碎片 %d · 已达顶级" % p.history_fragments
		_progress.min_value = 0
		_progress.max_value = 1
		_progress.value = 1
	else:
		_fragments_label.text = "历史碎片 %d / %d" % [p.history_fragments, next_threshold]
		_progress.min_value = current_threshold
		_progress.max_value = next_threshold
		_progress.value = p.history_fragments
	_money_label.text = "%d" % p.money
	_set_kv(_inv_label, "%d/%d · %d 两" % [p.inventory.size(), GameState.inventory_capacity(p), GameState.inventory_value(p)])

func _apply_avatar(player) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = player.color.darkened(0.12)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(38)
	_avatar.add_theme_stylebox_override("panel", sb)
	if not _avatar.has_node("avatar_image"):
		var tex := TextureRect.new()
		tex.name = "avatar_image"
		tex.anchor_right = 1.0
		tex.anchor_bottom = 1.0
		tex.offset_left = 5
		tex.offset_top = 5
		tex.offset_right = -5
		tex.offset_bottom = -5
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_avatar.add_child(tex)
	var avatar_image := _avatar.get_node("avatar_image") as TextureRect
	avatar_image.texture = GameConfig.get_avatar_texture(player.avatar_id, 72)

func _on_money_changed(_id: int, _amt: int) -> void:
	_refresh()

func _on_item_acquired(_id: int, _inst) -> void:
	_refresh()

func _on_round_started(_n: int) -> void:
	_refresh()

func _on_phase_changed(_p: String) -> void:
	_refresh()

func _on_history_changed(player_id: int, _total: int, _gained: int, _reason: String) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()

func _on_level_changed(player_id: int, _level: int) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()

func _on_skill_unlocked(player_id: int, _skill_id: String) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_refresh()
