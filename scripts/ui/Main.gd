extends Control
## 顶层场景，负责屏幕切换：MainMenu ↔ MapView ↔ AuctionScreen ↔ RankingScreen
## 所有屏幕都通过代码 instantiate，避免堆 .tscn

const MainMenuScreen := preload("res://scripts/ui/MainMenu.gd")
const MapSelectScreen := preload("res://scripts/ui/MapSelectScreen.gd")
const CharacterSetupScreen := preload("res://scripts/ui/CharacterSetupScreen.gd")
const MapViewScreen := preload("res://scripts/ui/MapView.gd")
const AuctionScreenUI := preload("res://scripts/ui/AuctionScreen.gd")
const RankingScreenUI := preload("res://scripts/ui/RankingScreen.gd")
const SettingsDialog := preload("res://scripts/ui/SettingsDialog.gd")
const CodexDialog := preload("res://scripts/ui/CodexDialog.gd")
const COIN_TEXTURE := "res://assets/ui/coin.png"

var _current_screen: Control = null
var _toast_layer: CanvasLayer = null
var _autoplay_mode: bool = false
var _pending_journey_mode: bool = false

func _ready() -> void:
	_setup_toast_layer()
	EventBus.toast.connect(_on_toast)
	EventBus.money_delta.connect(_on_money_delta)
	EventBus.auction_started.connect(_on_auction_started)
	EventBus.auction_finished.connect(_on_auction_finished)
	EventBus.game_finished.connect(_on_game_finished)
	EventBus.dialog_request.connect(_on_dialog_request)

	# OS.get_cmdline_args() 只返回引擎参数；用户参数（-- 之后）需要 get_cmdline_user_args()
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--autoplay" in args or "--autoplay" in user_args:
		_autoplay_mode = true
		GameConfig.DEBUG_AUTOPLAY = true
		print("[autoplay] enabled via cmdline")
		GameFlow.prepare_new_game()
		_show_map_view()
		await get_tree().process_frame
		GameFlow.start_new_game()
	else:
		_show_main_menu()

func _setup_toast_layer() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	add_child(_toast_layer)

func _swap_screen(new_screen: Control) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null
	add_child(new_screen)
	_current_screen = new_screen

func _show_main_menu() -> void:
	AudioManager.play_menu_bgm()
	var screen: Control = MainMenuScreen.new()
	screen.new_game_requested.connect(_on_new_game)
	screen.continue_requested.connect(_on_continue_game)
	screen.codex_requested.connect(_open_codex)
	screen.settings_requested.connect(_open_main_settings)
	screen.quit_requested.connect(_on_quit)
	_swap_screen(screen)

func _show_map_select() -> void:
	AudioManager.play_menu_bgm()
	var screen = MapSelectScreen.new()
	screen.single_player_requested.connect(_on_single_player_requested)
	screen.journey_mode_requested.connect(_on_journey_mode_requested)
	screen.back_requested.connect(_show_main_menu)
	_swap_screen(screen)

func _show_character_setup(map_id: String, journey_mode: bool = false) -> void:
	AudioManager.play_menu_bgm()
	_pending_journey_mode = journey_mode
	var screen = CharacterSetupScreen.new()
	screen.start_requested.connect(_on_character_start.bind(map_id))
	screen.back_requested.connect(_show_map_select)
	_swap_screen(screen)

func _show_map_view() -> void:
	AudioManager.play_game_bgm()
	var screen: Control = MapViewScreen.new()
	_swap_screen(screen)

func _show_auction(session: Dictionary) -> void:
	AudioManager.play_game_bgm()
	var screen: Control = AuctionScreenUI.new()
	screen.session = session
	_swap_screen(screen)

func _show_ranking() -> void:
	AudioManager.play_menu_bgm()
	var screen: Control = RankingScreenUI.new()
	screen.back_to_menu_requested.connect(_show_main_menu)
	_swap_screen(screen)

# ---- 信号 ----
func _on_new_game() -> void:
	_show_map_select()

func _on_single_player_requested(map_id: String) -> void:
	_show_character_setup(map_id, false)

func _on_journey_mode_requested(map_id: String) -> void:
	_show_character_setup(map_id, true)

func _on_character_start(profile: Dictionary, _map_id: String) -> void:
	# 先准备 GameState 再展示 MapView，确保棋子能创建
	SaveSystem.delete_save()
	if _pending_journey_mode:
		profile["game_mode"] = "journey"
	GameFlow.prepare_new_game(profile)
	_pending_journey_mode = false
	_show_map_view()
	await get_tree().process_frame
	GameFlow.start_new_game()

func _on_continue_game() -> void:
	if not SaveSystem.load_game():
		EventBus.toast.emit("没有可读取的存档", "warn")
		return
	_show_map_view()
	await get_tree().process_frame
	GameFlow.resume_game()

func _on_quit() -> void:
	get_tree().quit()

func _open_main_settings() -> void:
	var dlg := SettingsDialog.new()
	add_child(dlg)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	dlg.popup_centered()

func _open_codex() -> void:
	var dlg := CodexDialog.new()
	add_child(dlg)
	dlg.close_requested.connect(func():
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	dlg.popup_centered()

func _on_auction_started(session: Dictionary) -> void:
	_show_auction(session)

func _on_auction_finished() -> void:
	# 拍卖屏关闭，切回主地图（GameFlow 继续 round_end → 下一回合）
	# 如果是最后一回合(12) 后的拍卖，game_finished 会随后触发并切到 ranking
	_show_map_view()

func _on_game_finished() -> void:
	_show_ranking()
	if _autoplay_mode:
		var rk = RankingSystem.compute()
		print("[autoplay] === FINAL RANKING ===")
		for i in range(rk.size()):
			print("[autoplay] #%d  %s  total=%d  cash=%d  items=%d" % [i + 1, rk[i]["name"], rk[i]["total"], rk[i]["money"], rk[i]["items"]])
		# 给 RankingScreen 一秒展示再退出
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)

func _on_dialog_request(dialog_type: String, _payload: Dictionary) -> void:
	match dialog_type:
		"return_to_menu":
			GameFlow.abort()
			_show_main_menu()
		"restart_game":
			var profile := GameState.current_player_profile.duplicate(true)
			GameFlow.abort()
			GameFlow.prepare_new_game(profile)
			_show_map_view()
			await get_tree().process_frame
			GameFlow.start_new_game()

# ---- Toast ----
func _on_toast(text: String, tone: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	var color := Color.WHITE
	match tone:
		"good": color = Color("#9bd47a")
		"warn": color = Color("#e7b34a")
		"bad": color = Color("#e76a4a")
		"muted": color = Color("#a89a82")
		_: color = Color.WHITE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)

	var container := MarginContainer.new()
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 0.08
	container.anchor_bottom = 0.08
	container.add_theme_constant_override("margin_left", 0)
	container.add_theme_constant_override("margin_top", 0)
	container.add_child(panel)

	_toast_layer.add_child(container)
	container.position.x -= panel.size.x * 0.5
	# 动画：滑入 + 1.6s 消失
	var tween := create_tween()
	container.modulate.a = 0.0
	tween.tween_property(container, "modulate:a", 1.0, 0.18)
	tween.tween_interval(1.6)
	tween.tween_property(container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(container.queue_free)

func _on_money_delta(player_id: int, delta: int, reason: String) -> void:
	if player_id != GameConfig.HUMAN_PLAYER_ID:
		return
	var text := "%+d" % delta
	if reason != "":
		text += "  %s" % reason
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(COIN_TEXTURE)
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#9bd47a") if delta > 0 else Color("#e7b34a"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.62)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(row)
	var container := MarginContainer.new()
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 0.15
	container.anchor_bottom = 0.15
	container.add_child(panel)
	_toast_layer.add_child(container)
	container.position.x -= 140
	var tween := create_tween()
	container.modulate.a = 0.0
	tween.tween_property(container, "modulate:a", 1.0, 0.16)
	tween.tween_interval(1.1)
	tween.tween_property(container, "modulate:a", 0.0, 0.35)
	tween.tween_callback(container.queue_free)
