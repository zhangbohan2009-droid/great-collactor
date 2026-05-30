extends Node
## 用户设置：独立保存显示设置，不与单局存档绑定。

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var fullscreen: bool = false
var resolution: Vector2i = DEFAULT_RESOLUTION

func _ready() -> void:
	load_settings()
	apply_display_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	var width := int(cfg.get_value("display", "width", resolution.x))
	var height := int(cfg.get_value("display", "height", resolution.y))
	resolution = _normalize_resolution(Vector2i(width, height))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "width", resolution.x)
	cfg.set_value("display", "height", resolution.y)
	cfg.save(SETTINGS_PATH)

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display_settings()
	save_settings()

func set_resolution(value: Vector2i) -> void:
	resolution = _normalize_resolution(value)
	apply_display_settings()
	save_settings()

func apply_display_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	_center_window()

func is_current_resolution(value: Vector2i) -> bool:
	return resolution == value

func resolution_label(value: Vector2i) -> String:
	return "%d x %d" % [value.x, value.y]

func _normalize_resolution(value: Vector2i) -> Vector2i:
	for option in RESOLUTIONS:
		if option == value:
			return option
	return DEFAULT_RESOLUTION

func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var pos := (screen_size - resolution) / 2
	DisplayServer.window_set_position(Vector2i(max(0, pos.x), max(0, pos.y)))
