extends Node
## 单存档系统：保存/读取当前单局进度。

const SAVE_PATH := "user://savegame.json"

var _save_pending := false

func _ready() -> void:
	EventBus.round_ended.connect(func(_round_num): save_game())
	EventBus.auction_finished.connect(save_game)
	EventBus.money_delta.connect(func(_player_id, _delta, _reason): request_save())
	EventBus.item_acquired.connect(func(_player_id, _inst): request_save())
	EventBus.skill_unlocked.connect(func(_player_id, _skill_id): request_save())
	EventBus.tool_used.connect(func(_player_id, _tool_id): request_save())

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func has_resumable_save() -> bool:
	var data := _read_save_dict()
	if data.is_empty():
		return false
	var phase := str(data.get("current_phase", ""))
	if phase == "ranking":
		return false
	# 旅途模式没有回合上限，只要未进入结算阶段就可继续。
	var mode := str(data.get("game_mode", data.get("profile", {}).get("game_mode", "normal")))
	if mode == "journey":
		return true
	var round_num := int(data.get("current_round", 0))
	if round_num >= GameConfig.MAX_ROUNDS:
		return false
	return true

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var text := JSON.stringify(GameState.to_save_dict(), "\t")
	f.store_string(text)
	return true

func request_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	await get_tree().create_timer(0.25).timeout
	_save_pending = false
	save_game()

func load_game() -> bool:
	var parsed := _read_save_dict()
	if parsed.is_empty():
		return false
	GameState.load_from_save_dict(parsed)
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _read_save_dict() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
