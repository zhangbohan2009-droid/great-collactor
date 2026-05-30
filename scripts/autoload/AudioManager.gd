extends Node
## 全局音频反馈：BGM 循环与按钮交互音效。

const MENU_BGM := "res://assets/audio/bgm/main_menu_oriental_somber.ogg"
const GAME_BGM := "res://assets/audio/bgm/game_dragon_on_and_on.ogg"

const UI_SOUNDS: Dictionary = {
	"confirm": "res://assets/audio/ui/button_confirm.wav",
	"hover": "res://assets/audio/ui/button_hover.wav",
	"back": "res://assets/audio/ui/button_back.wav",
	"error": "res://assets/audio/ui/button_error.wav",
}

var _bgm_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _bgm_streams: Dictionary = {}
var _sounds: Dictionary = {}
var _current_bgm_id: String = ""

func _ready() -> void:
	_load_audio()
	_setup_players()
	get_tree().node_added.connect(_on_node_added)
	await get_tree().process_frame
	_bind_buttons(get_tree().root)
	play_menu_bgm()

func _load_audio() -> void:
	_bgm_streams["menu"] = _load_stream(MENU_BGM)
	_bgm_streams["game"] = _load_stream(GAME_BGM)
	for key in UI_SOUNDS.keys():
		var stream: AudioStream = _load_stream(str(UI_SOUNDS[key]))
		if stream != null:
			_sounds[key] = stream

func _load_stream(path: String) -> AudioStream:
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	return load(path)

func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_bgm_player.volume_db = -12.0
	_bgm_player.finished.connect(_replay_current_bgm)
	add_child(_bgm_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_ui_player.volume_db = -4.0
	add_child(_ui_player)

func play_menu_bgm() -> void:
	_play_bgm("menu")

func play_game_bgm() -> void:
	_play_bgm("game")

func _play_bgm(id: String) -> void:
	var stream: AudioStream = _bgm_streams.get(id)
	if stream == null:
		return
	if _current_bgm_id == id and _bgm_player.playing:
		return
	_current_bgm_id = id
	_bgm_player.stream = stream
	_bgm_player.play()

func _replay_current_bgm() -> void:
	if _current_bgm_id == "":
		return
	_play_bgm(_current_bgm_id)

func play_ui(sound_id: String = "confirm") -> void:
	var stream: AudioStream = _sounds.get(sound_id)
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.play()

func _on_node_added(node: Node) -> void:
	if node is Button:
		_bind_button(node)

func _bind_buttons(root: Node) -> void:
	if root is Button:
		_bind_button(root)
	for child in root.get_children():
		_bind_buttons(child)

func _bind_button(button: Button) -> void:
	if button.has_meta("audio_feedback_bound"):
		return
	button.set_meta("audio_feedback_bound", true)
	button.mouse_entered.connect(func():
		if not button.disabled:
			play_ui("hover")
	)
	button.pressed.connect(func():
		play_ui(_sound_for_button(button))
	)

func _sound_for_button(button: Button) -> String:
	var text := button.text
	if button.disabled:
		return "error"
	if text.contains("返回") or text.contains("关闭") or text.contains("退出") or text.contains("取消") or text.contains("离开"):
		return "back"
	return "confirm"
