extends Control
## David Rumsey 战国底图 + 区域染色 + Camera2D 缩放/拖动 + 玩家跟随。

const MapTileModel := preload("res://scripts/models/MapTile.gd")
const MapLayoutData := preload("res://scripts/data/MapLayout.gd")
const CityDialog := preload("res://scripts/ui/CityDialog.gd")
const BlackMarketDialog := preload("res://scripts/ui/BlackMarketDialog.gd")
const ScenicDialog := preload("res://scripts/ui/ScenicDialog.gd")
const TempleDialog := preload("res://scripts/ui/TempleDialog.gd")
const GamblingDialog := preload("res://scripts/ui/GamblingDialog.gd")
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
const MAP_EDGE_CROP_RATIO := 0.06

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
var _default_zoom := 1.0
var _dragging := false
var _last_drag_mouse_pos := Vector2.ZERO
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
	_default_zoom = _camera.zoom.x
	_center_camera_on_player(_cam_focus_player_id, true)
	set_process(true)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if GameConfig.DEBUG_AUTOPLAY:
		print("[mapview] ready")

func _process(delta: float) -> void:
	if _follow_enabled:
		_tick_follow_camera(delta)

func _input(event: InputEvent) -> void:
	if _handle_map_input(event):
		get_viewport().set_input_as_handled()

func _handle_map_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _is_pointer_over_hud_control():
					return false
				if _try_open_marker_at_mouse():
					_dragging = false
					return true
				_dragging = true
				_last_drag_mouse_pos = mb.position
				_disable_follow()
				return true
			var was_dragging := _dragging
			_dragging = false
			return was_dragging
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _is_pointer_over_hud_control():
				return false
			_zoom_at_mouse(1.15)
			return true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_pointer_over_hud_control():
				return false
			_zoom_at_mouse(1.0 / 1.15)
			return true
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var drag_delta := mm.position - _last_drag_mouse_pos
		_last_drag_mouse_pos = mm.position
		_camera.position -= drag_delta / _camera.zoom
		_clamp_camera()
		return true
	return false

func _is_pointer_over_hud_control() -> bool:
	var hovered: Node = get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered == _hud_root:
			return true
		hovered = hovered.get_parent()
	return false

func _try_open_marker_at_mouse() -> bool:
	if _camera == null or _tile_pixel_pos.is_empty():
		return false
	var world_pos := _camera.get_global_mouse_position()
	for i in range(GameState.map_tiles.size() - 1, -1, -1):
		if i >= _tile_pixel_pos.size():
			continue
		var tile = GameState.map_tiles[i]
		var base: Vector2 = _tile_pixel_pos[i]
		if tile.type == MapTileModel.Type.CITY:
			var card_rect := Rect2(base + tile.label_offset, NODE_CARD_SIZE)
			var icon_rect := Rect2(base - Vector2(34, 34), Vector2(68, 68))
			if card_rect.has_point(world_pos) or icon_rect.has_point(world_pos):
				_open_location_intro(tile)
				return true
		else:
			var poi_rect := Rect2(base - Vector2(38, 38), Vector2(76, 76))
			if poi_rect.has_point(world_pos):
				_open_location_intro(tile)
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
	_apply_base_map_crop()
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
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_dice_panel.offset_left = -248
	_dice_panel.offset_top = -344
	_dice_panel.offset_right = -66
	_dice_panel.offset_bottom = -16

	_timeline = TimelineUI.new()
	_hud_root.add_child(_timeline)
	_timeline.anchor_left = 1.0
	_timeline.anchor_right = 1.0
	_timeline.anchor_top = 1.0
	_timeline.anchor_bottom = 1.0
	_timeline.offset_left = -58
	_timeline.offset_top = -178
	_timeline.offset_right = -12
	_timeline.offset_bottom = -16

	_build_action_bar()
	_build_settings_button()
	_build_attribution()

func _make_camera_current() -> void:
	if _camera != null and _camera.is_inside_tree():
		_camera.make_current()

func _apply_base_map_crop() -> void:
	var visible_rect: Rect2 = _map_visible_rect()
	_base_map.region_enabled = true
	_base_map.region_rect = visible_rect
	_base_map.position = visible_rect.position

func _map_visible_rect() -> Rect2:
	var edge: float = min(_map_size.x, _map_size.y) * MAP_EDGE_CROP_RATIO
	var size: Vector2 = Vector2(
		max(1.0, _map_size.x - edge * 2.0),
		max(1.0, _map_size.y - edge * 2.0)
	)
	return Rect2(Vector2(edge, edge), size)

func _build_action_bar() -> void:
	_action_bar = Panel.new()
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.anchor_top = 1.0
	_action_bar.anchor_bottom = 1.0
	_action_bar.offset_left = -420
	_action_bar.offset_top = -70
	_action_bar.offset_right = 420
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

	var skill_btn := _make_action_button("◇ 技能树")
	skill_btn.pressed.connect(_open_skill_tree_dialog)
	row.add_child(skill_btn)

	var storage_btn := _make_action_button("▣ 仓库")
	storage_btn.pressed.connect(_open_storage_dialog)
	row.add_child(storage_btn)

	var tools_btn := _make_action_button("✦ 道具")
	tools_btn.pressed.connect(_open_tools_dialog)
	row.add_child(tools_btn)

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

func _open_skill_tree_dialog() -> void:
	var dlg := ProfileDialog.new()
	dlg.open_skill_tree_first()
	_open_overlay_dialog(dlg)

func _open_storage_dialog() -> void:
	var dlg := InventoryDialog.new()
	dlg.setup_mode("storage")
	_open_overlay_dialog(dlg)

func _open_tools_dialog() -> void:
	var dlg := InventoryDialog.new()
	dlg.setup_mode("tools")
	_open_overlay_dialog(dlg)

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
		var route_points := _route_points_for_indices(i, (i + 1) % _tile_pixel_pos.size())
		_add_route_path(route_points)
		_add_route_dot(_route_path_midpoint(route_points))

func _route_points_for_indices(from_index: int, to_index: int) -> Array[Vector2]:
	var points: Array[Vector2] = [_tile_pixel_pos[from_index]]
	var from_tile = GameState.map_tiles[from_index]
	var to_tile = GameState.map_tiles[to_index]
	match "%s>%s" % [from_tile.id, to_tile.id]:
		"chengdu>emei_temple":
			points.append_array([
				Vector2(2060, 2380),
				Vector2(1960, 2500),
			])
		"emei_temple>zhongnan_mountain":
			points.append_array([
				Vector2(2220, 2700),
				Vector2(2700, 2380),
				Vector2(3060, 1900),
			])
		"yingdu>chengdu":
			points.append_array([
				Vector2(3440, 2720),
				Vector2(2860, 2840),
				Vector2(2340, 2660),
			])
	points.append(_tile_pixel_pos[to_index])
	return points

func _movement_points_for_indices(from_index: int, to_index: int) -> Array[Vector2]:
	if from_index < 0 or to_index < 0 or from_index >= _tile_pixel_pos.size() or to_index >= _tile_pixel_pos.size():
		return []
	var n := GameState.map_tiles.size() if not GameState.map_tiles.is_empty() else GameConfig.TOTAL_TILES
	if to_index == posmod(from_index + 1, n):
		return _route_points_for_indices(from_index, to_index)
	if to_index == posmod(from_index - 1, n):
		var reversed_points: Array[Vector2] = _route_points_for_indices(to_index, from_index)
		reversed_points.reverse()
		return reversed_points
	return [_tile_pixel_pos[from_index], _tile_pixel_pos[to_index]]

func _add_route_path(points: Array[Vector2]) -> void:
	if points.size() < 2:
		return
	_add_polyline(points, 14.0, Color(0.09, 0.045, 0.02, 0.86))
	_add_polyline(points, 8.0, Color("#8a5a24"))
	_add_polyline(points, 3.0, Color(1.0, 0.82, 0.42, 0.98))

func _add_polyline(points: Array[Vector2], width: float, color: Color) -> void:
	var line := Line2D.new()
	for p in points:
		line.add_point(p)
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	_route_layer.add_child(line)

func _route_path_midpoint(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total_len := 0.0
	for i in range(points.size() - 1):
		total_len += points[i].distance_to(points[i + 1])
	if total_len <= 0.0:
		return points[0]
	var target_len := total_len * 0.5
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len := a.distance_to(b)
		if walked + seg_len >= target_len:
			var t := (target_len - walked) / seg_len
			return a.lerp(b, t)
		walked += seg_len
	return points[points.size() - 1]

func _add_line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var line := Line2D.new()
	line.add_point(a)
	line.add_point(b)
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	_route_layer.add_child(line)

func _add_route_dot(pos: Vector2) -> void:
	var dot := Panel.new()
	dot.size = Vector2(14, 14)
	dot.position = pos - dot.size * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f5e6c8")
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(7)
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

func _make_marker_button(tile, marker_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.size = marker_size
	btn.custom_minimum_size = marker_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "查看 %s 介绍" % tile.display_name
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var blank := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", blank)
	btn.add_theme_stylebox_override("hover", blank)
	btn.add_theme_stylebox_override("pressed", blank)
	btn.add_theme_stylebox_override("disabled", blank)
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.08, 1.08, 1.08, 1.0))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	btn.pressed.connect(func(): _open_location_intro(tile))
	return btn

func _make_city_path_icon(tile) -> Control:
	var root := _make_marker_button(tile, Vector2(50, 50))
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

func _make_city_card(tile) -> Button:
	var card := _make_marker_button(tile, NODE_CARD_SIZE)
	card.custom_minimum_size = NODE_CARD_SIZE
	card.size = NODE_CARD_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.90, 0.76, 0.95)
	sb.border_color = Color("#6b4828")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.1, 0.06, 0.04, 0.5)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 2)
	card.add_theme_stylebox_override("normal", sb)
	var hover_sb := sb.duplicate()
	hover_sb.bg_color = Color(1.0, 0.94, 0.80, 0.98)
	card.add_theme_stylebox_override("hover", hover_sb)
	var pressed_sb := sb.duplicate()
	pressed_sb.bg_color = Color("#d4a843")
	card.add_theme_stylebox_override("pressed", pressed_sb)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var display_text: String = tile.display_name
	var dot_idx := display_text.find(" · ")
	if dot_idx > 0:
		display_text = display_text.substr(0, dot_idx)
	var name_lbl := Label.new()
	name_lbl.text = display_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color("#2a1810"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "所属势力：%s" % (tile.country if tile.country != "" else "无")
	sub_lbl.tooltip_text = tile.ohm_source
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.32, 0.20, 0.12, 0.78))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)
	return card

func _make_flat_poi_icon(tile) -> Control:
	var root := _make_marker_button(tile, Vector2(56, 56))
	var color: Color = tile.color()
	match tile.type:
		MapTileModel.Type.BLACK_MARKET:
			var circle := Panel.new()
			circle.size = root.size
			var sb := StyleBoxFlat.new()
			sb.bg_color = color.darkened(0.12)
			sb.border_color = Color("#f5e6c8")
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(28)
			circle.add_theme_stylebox_override("panel", sb)
			circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(circle)
		MapTileModel.Type.SCENIC:
			var shadow := Panel.new()
			shadow.size = Vector2(48, 48)
			shadow.position = Vector2(6, 7)
			var shadow_sb := StyleBoxFlat.new()
			shadow_sb.bg_color = Color(0, 0, 0, 0.28)
			shadow_sb.set_corner_radius_all(24)
			shadow.add_theme_stylebox_override("panel", shadow_sb)
			shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(shadow)
			var badge := Panel.new()
			badge.size = Vector2(48, 48)
			badge.position = Vector2(4, 3)
			var dsb := StyleBoxFlat.new()
			dsb.bg_color = Color("#355f43")
			dsb.border_color = Color("#f5e6c8")
			dsb.set_border_width_all(3)
			dsb.set_corner_radius_all(24)
			badge.add_theme_stylebox_override("panel", dsb)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(badge)
			var far_mountain := Polygon2D.new()
			far_mountain.polygon = PackedVector2Array([Vector2(10, 35), Vector2(24, 16), Vector2(38, 35)])
			far_mountain.color = Color("#9bd47a")
			root.add_child(far_mountain)
			var near_mountain := Polygon2D.new()
			near_mountain.polygon = PackedVector2Array([Vector2(18, 37), Vector2(34, 18), Vector2(48, 37)])
			near_mountain.color = Color("#f5e6c8")
			root.add_child(near_mountain)
			var ground := Line2D.new()
			ground.add_point(Vector2(12, 38))
			ground.add_point(Vector2(44, 38))
			ground.width = 3
			ground.default_color = Color("#24402e")
			root.add_child(ground)
		MapTileModel.Type.TEMPLE:
			var tri := Polygon2D.new()
			tri.polygon = PackedVector2Array([Vector2(28, 6), Vector2(48, 45), Vector2(8, 45)])
			tri.color = color.darkened(0.1)
			root.add_child(tri)
			var outline := Line2D.new()
			outline.add_point(Vector2(28, 6))
			outline.add_point(Vector2(48, 45))
			outline.add_point(Vector2(8, 45))
			outline.add_point(Vector2(28, 6))
			outline.width = 2
			outline.default_color = Color("#f5e6c8")
			root.add_child(outline)
		MapTileModel.Type.GAMBLING:
			var base := Panel.new()
			base.size = root.size
			var sb := StyleBoxFlat.new()
			sb.bg_color = color.darkened(0.08)
			sb.border_color = Color("#f5e6c8")
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(10)
			base.add_theme_stylebox_override("panel", sb)
			base.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(base)
			var inset := Panel.new()
			inset.size = Vector2(34, 34)
			inset.position = Vector2(11, 11)
			var isb := StyleBoxFlat.new()
			isb.bg_color = Color("#2a1810")
			isb.border_color = Color("#d4a843")
			isb.set_border_width_all(2)
			isb.set_corner_radius_all(17)
			inset.add_theme_stylebox_override("panel", isb)
			inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(inset)
		_:
			var p := Panel.new()
			p.size = root.size
			root.add_child(p)
	var lbl := Label.new()
	lbl.text = "山" if tile.type == MapTileModel.Type.SCENIC else tile.type_label()
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15 if tile.type == MapTileModel.Type.SCENIC else 18)
	lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	if tile.type == MapTileModel.Type.SCENIC:
		lbl.offset_top = 20
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
	return GameConfig.get_avatar_texture(player.avatar_id, 32)

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
	var visible_rect: Rect2 = _map_visible_rect()
	var cover_zoom: float = max(vp.x / visible_rect.size.x, vp.y / visible_rect.size.y) * 1.04
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
	var visible_rect: Rect2 = _map_visible_rect()
	var min_pos: Vector2 = visible_rect.position + half
	var max_pos: Vector2 = visible_rect.end - half
	_camera.position.x = visible_rect.get_center().x if min_pos.x > max_pos.x else clampf(_camera.position.x, min_pos.x, max_pos.x)
	_camera.position.y = visible_rect.get_center().y if min_pos.y > max_pos.y else clampf(_camera.position.y, min_pos.y, max_pos.y)

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
		# 同时复位缩放与位置：把视角大小恢复成默认值，再居中到玩家。
		_camera.zoom = Vector2.ONE * clampf(_default_zoom, _min_zoom, _max_zoom)
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
		var n := GameState.map_tiles.size() if not GameState.map_tiles.is_empty() else GameConfig.TOTAL_TILES
		var direction := GameFlow.get_last_move_direction(player_id)
		var i := from_index
		while i != to_index:
			i = posmod(i + direction, n)
			path.append(i)
	if _follow_enabled and player_id == GameConfig.HUMAN_PLAYER_ID:
		_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
	var tween := create_tween()
	var offset := _token_offset_for(player_id)
	var prev_idx := from_index
	for idx in path:
		if idx < 0 or idx >= _tile_pixel_pos.size():
			continue
		_tween_token_step(tween, token, prev_idx, idx, offset)
		prev_idx = idx
	tween.tween_callback(func():
		if _follow_enabled:
			_cam_focus_player_id = GameConfig.HUMAN_PLAYER_ID
		_show_region_visit_bonus(player_id, to_index)
		GameState.mark_player_ready(player_id)
	)

func _tween_token_step(tween: Tween, token: Control, from_index: int, to_index: int, offset: Vector2) -> void:
	var points := _movement_points_for_indices(from_index, to_index)
	if points.size() < 2:
		if to_index >= 0 and to_index < _tile_pixel_pos.size():
			var fallback_pos: Vector2 = _tile_pixel_pos[to_index] - token.size * 0.5 + offset
			tween.tween_property(token, "position", fallback_pos, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	var total_len := 0.0
	for i in range(points.size() - 1):
		total_len += points[i].distance_to(points[i + 1])
	if total_len <= 0.0:
		return
	var step_duration := clampf(total_len / 900.0, 0.28, 0.62)
	for i in range(1, points.size()):
		var seg_len := points[i - 1].distance_to(points[i])
		var seg_duration: float = max(0.06, step_duration * (seg_len / total_len))
		var target_pos: Vector2 = points[i] - token.size * 0.5 + offset
		tween.tween_property(token, "position", target_pos, seg_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_region_visit_bonus(player_id: int, tile_index: int) -> void:
	var tile = GameState.tile_at(tile_index)
	if tile == null:
		return
	var count := GameState.mark_region_visited(tile)
	if count <= 0 or tile_index < 0 or tile_index >= _tile_pixel_pos.size():
		return
	var label_text := "%s +%d" % [_region_display_name(tile), count]
	var color := _region_bonus_color(count)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22 if player_id == GameConfig.HUMAN_PLAYER_ID else 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = _tile_pixel_pos[tile_index] + Vector2(-58, -88 - player_id * 18)
	label.size = Vector2(116, 30)
	label.z_index = 300
	_nodes_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 42, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.25)
	tween.tween_callback(label.queue_free)

func _region_display_name(tile) -> String:
	var country := str(tile.country)
	if country != "":
		return country
	return str(tile.display_name)

func _region_bonus_color(count: int) -> Color:
	if count <= 1:
		return Color("#9bd47a")
	if count == 2:
		return Color("#7da8d4")
	if count == 3:
		return Color("#d4a843")
	return Color("#ff8a4a")

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
		MapTileModel.Type.GAMBLING:
			var d5 := GamblingDialog.new()
			d5.setup(tile)
			dlg = d5
	if dlg == null:
		GameFlow.human_finish_tile_event()
		return
	_active_dialog = dlg
	dlg.close_requested.connect(_on_dialog_closed)
	if dlg.has_method("set_intro_callback"):
		dlg.set_intro_callback(Callable(self, "_open_tutorial_overlay").bind(tile.type_key_str()))
	add_child(dlg)
	dlg.popup_centered()

func _on_dialog_closed() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	GameFlow.human_finish_tile_event()

func _open_location_intro(tile) -> void:
	if tile == null:
		return
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null
	_pending_tile_index = -1
	var dlg := IntroDialog.new()
	dlg.setup_location(tile)
	dlg.close_requested.connect(_on_intro_closed_review)
	_active_dialog = dlg
	add_child(dlg)
	dlg.popup_centered()

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

func _open_tutorial_overlay(type_key: String) -> void:
	var dlg := IntroDialog.new()
	dlg.setup(type_key, false)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()
