extends Control
## David Rumsey 战国底图 + 区域染色 + Camera2D 缩放/拖动 + 玩家跟随。

const MapTileModel := preload("res://scripts/models/MapTile.gd")
const MapLayoutData := preload("res://scripts/data/MapLayout.gd")
const CityDialog := preload("res://scripts/ui/CityDialog.gd")
const BlackMarketDialog := preload("res://scripts/ui/BlackMarketDialog.gd")
const ScenicDialog := preload("res://scripts/ui/ScenicDialog.gd")
const TempleDialog := preload("res://scripts/ui/TempleDialog.gd")
const IntroDialog := preload("res://scripts/ui/IntroDialog.gd")
const PlayerHUDUI := preload("res://scripts/ui/PlayerHUD.gd")
const PlayersStatusBarUI := preload("res://scripts/ui/PlayersStatusBar.gd")
const DicePanelUI := preload("res://scripts/ui/DicePanel.gd")
const TimelineUI := preload("res://scripts/ui/Timeline.gd")
const ProfileDialog := preload("res://scripts/ui/ProfileDialog.gd")
const InventoryDialog := preload("res://scripts/ui/InventoryDialog.gd")
const RankingDialog := preload("res://scripts/ui/RankingDialog.gd")
const SettingsDialog := preload("res://scripts/ui/SettingsDialog.gd")

const BASE_MAP_PATH := "res://assets/map/base_rumsey.png"
const NODE_CARD_SIZE := Vector2(108, 64)
const TOKEN_SIZE := Vector2(38, 38)
const CAM_LERP := 6.0
const MAX_ZOOM_MULT := 4.0
const MAP_EDGE_CROP_RATIO := 0.035

var _world: Node2D
var _base_map: Sprite2D
var _regions_layer: Node2D
var _route_layer: Node2D
var _nodes_layer: Node2D
var _tokens_layer: Node2D
var _camera: Camera2D
var _hud_layer: CanvasLayer
var _hud_root: Control

var _tile_pixel_pos: Array = []
var _node_cards: Array = []
var _player_tokens: Dictionary = {}
var _map_meta: Dictionary = {}
var _map_size := Vector2(6144, 4589)
var _min_zoom := 0.25
var _max_zoom := 1.0
var _dragging := false
var _follow_enabled := true
var _cam_focus_player_id := GameConfig.HUMAN_PLAYER_ID

var _hud: Control
var _status_bar: Control
var _dice_panel: Control
var _timeline: Control
var _follow_btn: Button
var _action_bar: Control
var _active_dialog: Window = null
var _pending_tile_index := -1

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_map_meta = MapLayoutData.load_base_map_meta()
	_map_size = MapLayoutData.image_size(_map_meta)
	_build_ui()
	_connect_signals()
	await get_tree().process_frame
	_layout_map()
	_update_zoom_limits()
	_center_camera_on_player(_cam_focus_player_id, true)
	set_process(true)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if GameConfig.DEBUG_AUTOPLAY:
		print("[mapview] ready")

func _process(delta: float) -> void:
	if _follow_enabled:
		_tick_follow_camera(delta)

func _gui_input(event: InputEvent) -> void:
	if _handle_map_input(event):
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	_handle_map_input(event)

func _handle_map_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_disable_follow()
			return true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.15)
			return true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 / 1.15)
			return true
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_camera.position -= mm.relative / _camera.zoom
		_clamp_camera()
		return true
	return false

func _on_viewport_resized() -> void:
	_update_zoom_limits()
	_clamp_camera()
	if _follow_enabled:
		_center_camera_on_player(_cam_focus_player_id, false)

func _build_ui() -> void:
	_world = Node2D.new()
	add_child(_world)

	_base_map = Sprite2D.new()
	_base_map.texture = load(BASE_MAP_PATH)
	_base_map.centered = false
	_world.add_child(_base_map)

	_regions_layer = Node2D.new()
	_world.add_child(_regions_layer)
	_route_layer = Node2D.new()
	_world.add_child(_route_layer)
	_nodes_layer = Node2D.new()
	_world.add_child(_nodes_layer)
	_tokens_layer = Node2D.new()
	_world.add_child(_tokens_layer)

	_camera = Camera2D.new()
	_camera.enabled = true
	add_child(_camera)
	call_deferred("_make_camera_current")

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.anchor_right = 1.0
	_hud_root.anchor_bottom = 1.0
	_hud_layer.add_child(_hud_root)

	_hud = PlayerHUDUI.new()
	_hud_root.add_child(_hud)

	_status_bar = PlayersStatusBarUI.new()
	_status_bar.position = Vector2(16, 154)
	_hud_root.add_child(_status_bar)

	_dice_panel = DicePanelUI.new()
	_hud_root.add_child(_dice_panel)
	_dice_panel.anchor_left = 1.0
	_dice_panel.anchor_top = 1.0
	_dice_panel.anchor_right = 1.0
	_dice_panel.anchor_bottom = 1.0
	_dice_panel.offset_left = -226
	_dice_panel.offset_top = -210
	_dice_panel.offset_right = -66
	_dice_panel.offset_bottom = -16

	_timeline = TimelineUI.new()
	_hud_root.add_child(_timeline)
	_timeline.anchor_left = 1.0
	_timeline.anchor_right = 1.0
	_timeline.anchor_top = 1.0
	_timeline.anchor_bottom = 1.0
	_timeline.offset_left = -58
	_timeline.offset_top = -364
	_timeline.offset_right = -12
	_timeline.offset_bottom = -16

	_build_action_bar()
	_build_settings_button()
	_build_attribution()

func _make_camera_current() -> void:
	if _camera != null and _camera.is_inside_tree():
		_camera.make_current()

func _build_action_bar() -> void:
	_action_bar = Panel.new()
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.anchor_top = 1.0
	_action_bar.anchor_bottom = 1.0
	_action_bar.offset_left = -270
	_action_bar.offset_top = -70
	_action_bar.offset_right = 270
	_action_bar.offset_bottom = -16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.045, 0.025, 0.76)
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	_action_bar.add_theme_stylebox_override("panel", sb)
	_hud_root.add_child(_action_bar)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -10
	row.offset_bottom = -8
	_action_bar.add_child(row)

	var profile_btn := _make_action_button("◎ 个人主页")
	profile_btn.pressed.connect(_open_profile_dialog)
	row.add_child(profile_btn)

	var inventory_btn := _make_action_button("▣ 背包")
	inventory_btn.pressed.connect(_open_inventory_dialog)
	row.add_child(inventory_btn)

	var ranking_btn := _make_action_button("♛ 排行榜")
	ranking_btn.pressed.connect(_open_ranking_dialog)
	row.add_child(ranking_btn)

	_follow_btn = Button.new()
	_follow_btn.text = "⌖ 视角跟随"
	_follow_btn.toggle_mode = true
	_follow_btn.button_pressed = true
	_follow_btn.tooltip_text = "镜头跟随玩家；拖动或滚轮缩放会自动取消"
	_follow_btn.custom_minimum_size = Vector2(118, 38)
	_apply_action_button_style(_follow_btn)
	_follow_btn.pressed.connect(_on_follow_button_pressed)
	row.add_child(_follow_btn)

func _build_settings_button() -> void:
	var btn := _make_action_button("设置")
	btn.custom_minimum_size = Vector2(86, 38)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -104
	btn.offset_top = 16
	btn.offset_right = -16
	btn.offset_bottom = 54
	btn.pressed.connect(_open_settings_dialog)
	_hud_root.add_child(btn)

func _make_action_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(124, 38)
	_apply_action_button_style(btn)
	return btn

func _apply_action_button_style(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1f15")
	sb.border_color = Color("#d4a843")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	var hover := sb.duplicate()
	hover.bg_color = Color("#3a2810")
	var pressed := sb.duplicate()
	pressed.bg_color = Color("#5a3b12")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("#f5e6c8"))

func _build_attribution() -> void:
	var label := Label.new()
	label.text = "%s · %s" % [
		str(_map_meta.get("attribution", "David Rumsey Historical Map Collection")),
		str(_map_meta.get("period", "Warring States period")),
	]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 0.78))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = -320
	label.offset_top = -26
	label.offset_right = -8
	label.offset_bottom = -4
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_root.add_child(label)

func _open_profile_dialog() -> void:
	_open_overlay_dialog(ProfileDialog.new())

func _open_inventory_dialog() -> void:
	_open_overlay_dialog(InventoryDialog.new())

func _open_ranking_dialog() -> void:
	_open_overlay_dialog(RankingDialog.new())

func _open_settings_dialog() -> void:
	var dlg := SettingsDialog.new()
	dlg.show_game_actions = true
	dlg.return_to_menu_requested.connect(func():
		SaveSystem.save_game()
		EventBus.dialog_request.emit("return_to_menu", {})
		dlg.queue_free()
	)
	dlg.restart_requested.connect(func():
		SaveSystem.delete_save()
		EventBus.dialog_request.emit("restart_game", {})
		dlg.queue_free()
	)
	_open_overlay_dialog(dlg)

func _open_overlay_dialog(dlg: Window) -> void:
	add_child(dlg)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	dlg.popup_centered()

func _connect_signals() -> void:
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.tile_event_started.connect(_on_tile_event_started)
	EventBus.dice_rolled.connect(_on_dice_rolled)

func _layout_map() -> void:
	_compute_pixel_positions()
	_redraw_regions()
	_redraw_routes()
	_redraw_nodes()
	_redraw_all_tokens()

func _compute_pixel_positions() -> void:
	_tile_pixel_pos.clear()
	for tile in GameState.map_tiles:
		_tile_pixel_pos.append(MapLayoutData.geo_to_image_px(tile.lng, tile.lat, _map_meta))

func _redraw_regions() -> void:
	for child in _regions_layer.get_children():
		child.queue_free()
	for region in MapLayoutData.historical_regions():
		var points := PackedVector2Array()
		for pair in region.get("points", []):
			points.append(MapLayoutData.geo_to_image_px(float(pair[0]), float(pair[1]), _map_meta))
		if points.size() < 3:
			continue
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = region.get("color", Color(1, 1, 1, 0.12))
		_regions_layer.add_child(poly)

func _redraw_routes() -> void:
	for child in _route_layer.get_children():
		child.queue_free()
	if _tile_pixel_pos.size() < 2:
		return
	for i in range(_tile_pixel_pos.size()):
		var a: Vector2 = _tile_pixel_pos[i]
		var b: Vector2 = _tile_pixel_pos[(i + 1) % _tile_pixel_pos.size()]
		_add_line(a, b, 10.0, Color(0.12, 0.07, 0.03, 0.88))
		_add_line(a, b, 5.0, Color(0.95, 0.72, 0.30, 0.96))
		_add_route_dot((a + b) * 0.5)

func _add_line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var line := Line2D.new()
	line.add_point(a)
	line.add_point(b)
	line.width = width
	line.default_color = color
	_route_layer.add_child(line)

func _add_route_dot(pos: Vector2) -> void:
	var dot := Panel.new()
	dot.size = Vector2(11, 11)
	dot.position = pos - dot.size * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.12, 0.07, 0.95)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_layer.add_child(dot)

func _redraw_nodes() -> void:
	for card in _node_cards:
		if is_instance_valid(card):
			card.queue_free()
	_node_cards.clear()
	for i in range(GameState.map_tiles.size()):
		var tile = GameState.map_tiles[i]
		if tile.type == MapTileModel.Type.CITY:
			var marker := _make_city_path_icon(tile)
			marker.position = _tile_pixel_pos[i] - marker.size * 0.5
			_nodes_layer.add_child(marker)
			_node_cards.append(marker)
			var card := _make_city_card(tile)
			card.position = _tile_pixel_pos[i] + tile.label_offset
			_nodes_layer.add_child(card)
			_node_cards.append(card)
		else:
			var icon := _make_flat_poi_icon(tile)
			icon.position = _tile_pixel_pos[i] - icon.size * 0.5
			_nodes_layer.add_child(icon)
			_node_cards.append(icon)

func _node_marker_position(tile, index: int, marker: CanvasItem) -> Vector2:
	var base: Vector2 = _tile_pixel_pos[index]
	if tile.type == MapTileModel.Type.CITY:
		return base + tile.label_offset
	if marker is Control:
		var ctrl := marker as Control
		return base - ctrl.size * 0.5
	return base

func _make_node_marker(tile) -> CanvasItem:
	if tile.type != MapTileModel.Type.CITY:
		return _make_flat_poi_icon(tile)
	return _make_city_card(tile)

func _make_city_path_icon(tile) -> Control:
	var root := Control.new()
	root.size = Vector2(50, 50)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := Panel.new()
	base.size = root.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = tile.color().darkened(0.18)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(25)
	base.add_theme_stylebox_override("panel", sb)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	var inner := Panel.new()
	inner.size = Vector2(28, 28)
	inner.position = Vector2(11, 11)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("#2a1810")
	isb.border_color = Color("#d4a843")
	isb.set_border_width_all(2)
	isb.set_corner_radius_all(14)
	inner.add_theme_stylebox_override("panel", isb)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var lbl := Label.new()
	lbl.text = "城"
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)
	return root

func _make_city_card(tile) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = NODE_CARD_SIZE
	card.size = NODE_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.90, 0.76, 0.95)
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.1, 0.06, 0.04, 0.5)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 2)
	card.add_theme_stylebox_override("panel", sb)

	var pedestal := Panel.new()
	pedestal.size = Vector2(42, 24)
	pedestal.position = Vector2((NODE_CARD_SIZE.x - pedestal.size.x) * 0.5, NODE_CARD_SIZE.y - 10)
	var psb := StyleBoxFlat.new()
	psb.bg_color = tile.color().darkened(0.20)
	psb.border_color = Color("#1f1610")
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(12)
	pedestal.add_theme_stylebox_override("panel", psb)
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pedestal)
	var plbl := Label.new()
	plbl.text = "城"
	plbl.anchor_right = 1.0
	plbl.anchor_bottom = 1.0
	plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plbl.add_theme_font_size_override("font_size", 13)
	plbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	plbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	plbl.add_theme_constant_override("outline_size", 2)
	pedestal.add_child(plbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 6
	hbox.offset_top = 4
	hbox.offset_right = -6
	hbox.offset_bottom = -4
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(28, 28)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = tile.color()
	bsb.border_color = Color("#1f1610")
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(badge)

	var blbl := Label.new()
	blbl.text = tile.type_label()
	blbl.add_theme_font_size_override("font_size", 16)
	blbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	blbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	blbl.add_theme_constant_override("outline_size", 2)
	blbl.size = Vector2(28, 28)
	blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(blbl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var display_text: String = tile.display_name
	var dot_idx := display_text.find(" · ")
	if dot_idx > 0:
		display_text = display_text.substr(0, dot_idx)
	var name_lbl := Label.new()
	name_lbl.text = display_text
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color("#2a1810"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = tile.country if tile.country != "" else tile.ohm_source
	sub_lbl.tooltip_text = tile.ohm_source
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.32, 0.20, 0.12, 0.78))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)
	return card

func _make_flat_poi_icon(tile) -> Control:
	var root := Control.new()
	root.size = Vector2(46, 46)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = tile.color()
	match tile.type:
		MapTileModel.Type.BLACK_MARKET:
			var circle := Panel.new()
			circle.size = root.size
			var sb := StyleBoxFlat.new()
			sb.bg_color = color.darkened(0.12)
			sb.border_color = Color("#f5e6c8")
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(23)
			circle.add_theme_stylebox_override("panel", sb)
			circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(circle)
		MapTileModel.Type.SCENIC:
			var diamond := Panel.new()
			diamond.size = Vector2(34, 34)
			diamond.position = Vector2(6, 6)
			diamond.rotation = PI / 4.0
			var dsb := StyleBoxFlat.new()
			dsb.bg_color = color.darkened(0.1)
			dsb.border_color = Color("#f5e6c8")
			dsb.set_border_width_all(2)
			dsb.set_corner_radius_all(5)
			diamond.add_theme_stylebox_override("panel", dsb)
			diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(diamond)
		MapTileModel.Type.TEMPLE:
			var tri := Polygon2D.new()
			tri.polygon = PackedVector2Array([Vector2(23, 4), Vector2(42, 39), Vector2(4, 39)])
			tri.color = color.darkened(0.1)
			root.add_child(tri)
			var outline := Line2D.new()
			outline.add_point(Vector2(23, 4))
			outline.add_point(Vector2(42, 39))
			outline.add_point(Vector2(4, 39))
			outline.add_point(Vector2(23, 4))
			outline.width = 2
			outline.default_color = Color("#f5e6c8")
			root.add_child(outline)
		_:
			var p := Panel.new()
			p.size = root.size
			root.add_child(p)
	var lbl := Label.new()
	lbl.text = tile.type_label()
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)
	return root

func _make_token(player) -> Control:
	var root := Control.new()
	root.size = TOKEN_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shadow := Panel.new()
	shadow.size = TOKEN_SIZE
	shadow.position = Vector2(2, 3)
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0, 0, 0, 0.34)
	shadow_sb.set_corner_radius_all(int(TOKEN_SIZE.x * 0.5))
	shadow.add_theme_stylebox_override("panel", shadow_sb)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var pnl := Panel.new()
	pnl.size = TOKEN_SIZE
	pnl.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = player.color.darkened(0.08)
	sb.border_color = Color("#f5e6c8")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(TOKEN_SIZE.x * 0.5))
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pnl)

	var avatar := TextureRect.new()
	avatar.texture = _avatar_texture_for(player)
	avatar.anchor_right = 1.0
	avatar.anchor_bottom = 1.0
	avatar.offset_left = 4
	avatar.offset_top = 4
	avatar.offset_right = -4
	avatar.offset_bottom = -4
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pnl.add_child(avatar)
	return root

func _avatar_texture_for(player) -> Texture2D:
	var path := str(GameConfig.AVATAR_TEXTURES.get(player.avatar_id, GameConfig.AVATAR_TEXTURES["collector_gold"]))
	return load(path)

func _redraw_all_tokens() -> void:
	for id in _player_tokens.keys():
		var token = _player_tokens[id]
		if is_instance_valid(token):
			token.queue_free()
	_player_tokens.clear()
	for p in GameState.players:
		var token := _make_token(p)
		_player_tokens[p.id] = token
		_tokens_layer.add_child(token)
		_position_token(p.id, p.position)

func _position_token(player_id: int, tile_index: int) -> void:
	if not _player_tokens.has(player_id):
		return
	if tile_index < 0 or tile_index >= _tile_pixel_pos.size():
		return
	var token: Control = _player_tokens[player_id]
	token.position = _tile_pixel_pos[tile_index] - token.size * 0.5 + _token_offset_for(player_id)

func _token_offset_for(player_id: int) -> Vector2:
	match player_id:
		0: return Vector2(-22, 24)
		1: return Vector2(22, 24)
		2: return Vector2(0, -34)
		_: return Vector2.ZERO

func _update_zoom_limits() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		return
	var cover_zoom: float = max(vp.x / _map_size.x, vp.y / _map_size.y) * 1.08
	var content_zoom: float = _fit_interactive_zoom(vp)
	_min_zoom = clampf(min(max(cover_zoom, 0.15), content_zoom), 0.15, 1.0)
	_max_zoom = _min_zoom * MAX_ZOOM_MULT
	_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x, _min_zoom, _max_zoom)

func _fit_interactive_zoom(vp: Vector2) -> float:
	if _tile_pixel_pos.is_empty():
		return 1.0
	var min_p: Vector2 = _tile_pixel_pos[0]
	var max_p: Vector2 = _tile_pixel_pos[0]
	for p in _tile_pixel_pos:
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)
	var size: Vector2 = max_p - min_p + Vector2(520, 420)
	return min(vp.x / max(1.0, size.x), vp.y / max(1.0, size.y))

func _zoom_at_mouse(factor: float) -> void:
	_disable_follow()
	var before := _camera.get_global_mouse_position()
	_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x * factor, _min_zoom, _max_zoom)
	var after := _camera.get_global_mouse_position()
	_camera.position += before - after
	_clamp_camera()

func _clamp_camera() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		return
	var half := vp * 0.5 / _camera.zoom
	var edge: float = min(_map_size.x, _map_size.y) * MAP_EDGE_CROP_RATIO
	var min_pos := half + Vector2(edge, edge)
	var max_pos := _map_size - half - Vector2(edge, edge)
	_camera.position.x = _map_size.x * 0.5 if min_pos.x > max_pos.x else clampf(_camera.position.x, min_pos.x, max_pos.x)
	_camera.position.y = _map_size.y * 0.5 if min_pos.y > max_pos.y else clampf(_camera.position.y, min_pos.y, max_pos.y)

func _tick_follow_camera(delta: float) -> void:
	var target := _camera_target_for(_cam_focus_player_id)
	if target == Vector2.INF:
		return
	_camera.position = _camera.position.lerp(target, clampf(delta * CAM_LERP, 0.0, 1.0))
	_clamp_camera()

func _camera_target_for(player_id: int) -> Vector2:
	if not _player_tokens.has(player_id):
		return Vector2.INF
	var token: Control = _player_tokens[player_id]
	return token.position + token.size * 0.5

func _center_camera_on_player(player_id: int, immediate: bool) -> void:
	var target := _camera_target_for(player_id)
	if target == Vector2.INF:
		return
	_camera.position = target if immediate else _camera.position.lerp(target, 0.35)
	_clamp_camera()

func _disable_follow() -> void:
	if not _follow_enabled:
		return
	_follow_enabled = false
	if _follow_btn != null:
		_follow_btn.button_pressed = false

func _on_follow_button_pressed() -> void:
	_follow_enabled = _follow_btn.button_pressed
	if _follow_enabled:
		_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
		_center_camera_on_player(_cam_focus_player_id, false)

func _on_dice_rolled(player_id: int, _value: int) -> void:
	if player_id == GameConfig.HUMAN_PLAYER_ID and _follow_enabled:
		_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID

func _on_player_moved(player_id: int, from_index: int, to_index: int) -> void:
	if GameConfig.DEBUG_AUTOPLAY:
		print("[mapview] _on_player_moved p%d %d->%d" % [player_id, from_index, to_index])
	if player_id == GameConfig.HUMAN_PLAYER_ID:
		_follow_enabled = true
		_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
		if _follow_btn != null:
			_follow_btn.button_pressed = true
	var token = _player_tokens.get(player_id)
	if token == null:
		GameState.mark_player_ready(player_id)
		return
	var path: Array[int] = []
	if from_index == to_index:
		path.append(to_index)
	else:
		var n := GameConfig.TOTAL_TILES
		var i := from_index
		while i != to_index:
			i = (i + 1) % n
			path.append(i)
	if _follow_enabled and player_id == GameConfig.HUMAN_PLAYER_ID:
		_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
	var tween := create_tween()
	var offset := _token_offset_for(player_id)
	for idx in path:
		if idx < 0 or idx >= _tile_pixel_pos.size():
			continue
		var target_pos: Vector2 = _tile_pixel_pos[idx] - token.size * 0.5 + offset
		tween.tween_property(token, "position", target_pos, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if _follow_enabled:
			_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
		GameState.mark_player_ready(player_id)
	)

func _on_tile_event_started(player_id: int, tile_index: int) -> void:
	if player_id != GameConfig.HUMAN_PLAYER_ID:
		return
	if GameConfig.DEBUG_AUTOPLAY:
		return
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	var tile = GameState.tile_at(tile_index)
	if tile == null:
		GameFlow.human_finish_tile_event()
		return
	var type_key: String = tile.type_key_str()
	if not GameState.has_seen_intro(type_key):
		_pending_tile_index = tile_index
		_open_intro_dialog(type_key, true)
		return
	_open_event_dialog_for_tile(tile)

func _open_event_dialog_for_tile(tile) -> void:
	var dlg: Window = null
	match tile.type:
		MapTileModel.Type.CITY:
			var d := CityDialog.new()
			d.setup(tile)
			dlg = d
		MapTileModel.Type.BLACK_MARKET:
			var d2 := BlackMarketDialog.new()
			d2.setup(tile)
			dlg = d2
		MapTileModel.Type.SCENIC:
			var d3 := ScenicDialog.new()
			d3.setup(tile)
			dlg = d3
		MapTileModel.Type.TEMPLE:
			var d4 := TempleDialog.new()
			d4.setup(tile)
			dlg = d4
	if dlg == null:
		GameFlow.human_finish_tile_event()
		return
	_active_dialog = dlg
	dlg.close_requested.connect(_on_dialog_closed)
	if dlg.has_method("set_intro_callback"):
		dlg.set_intro_callback(Callable(self, "_on_show_intro_again").bind(tile.type_key_str()))
	add_child(dlg)
	dlg.popup_centered()

func _on_dialog_closed() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	GameFlow.human_finish_tile_event()

func _open_intro_dialog(type_key: String, first_time: bool) -> void:
	var dlg := IntroDialog.new()
	dlg.setup(type_key, first_time)
	if first_time:
		dlg.close_requested.connect(_on_intro_closed_first_time)
	else:
		dlg.close_requested.connect(_on_intro_closed_review)
	_active_dialog = dlg
	add_child(dlg)
	dlg.popup_centered()

func _on_intro_closed_first_time() -> void:
	if _active_dialog != null:
		var tk = _active_dialog.get_meta("type_key", "")
		if tk != "":
			GameState.mark_intro_seen(tk)
		_active_dialog.queue_free()
		_active_dialog = null
	if _pending_tile_index >= 0:
		var tile = GameState.tile_at(_pending_tile_index)
		_pending_tile_index = -1
		if tile != null:
			_open_event_dialog_for_tile(tile)
			return
	GameFlow.human_finish_tile_event()

func _on_intro_closed_review() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	if _pending_tile_index >= 0:
		var tile = GameState.tile_at(_pending_tile_index)
		_pending_tile_index = -1
		if tile != null:
			_open_event_dialog_for_tile(tile)

func _on_show_intro_again(type_key: String) -> void:
	if _active_dialog != null:
		_pending_tile_index = -1
		var human = GameState.human_player()
		if human != null:
			for i in range(GameState.map_tiles.size()):
				var t = GameState.map_tiles[i]
				if t.type_key_str() == type_key and human.position == i:
					_pending_tile_index = i
					break
		_active_dialog.queue_free()
		_active_dialog = null
	_open_intro_dialog(type_key, false)
