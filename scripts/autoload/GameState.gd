extends Node
## 全局游戏状态（类似千年项目里的 systems/state.js）
## 持有 玩家列表 / 地图 / 当前回合 / 当前阶段 / 拍卖会话

const PlayerModel := preload("res://scripts/models/Player.gd")
const MapTileModel := preload("res://scripts/models/MapTile.gd")
const ItemInstanceModel := preload("res://scripts/models/ItemInstance.gd")
const MapLayoutData := preload("res://scripts/data/MapLayout.gd")
const ItemsDBRef := preload("res://scripts/data/ItemsDB.gd")

var players: Array = []                # Array[Player]
var map_tiles: Array = []              # Array[MapTile]
var current_round: int = 0
var current_phase: String = "main_menu"
var auction_session: Dictionary = {}
var rng := RandomNumberGenerator.new()
# 玩家（人类）已看过的节点类型介绍：键为 type_key_str()，值为 true
var _seen_intro: Dictionary = {}
var codex_item_ids: Dictionary = {}
var city_visit_counts: Dictionary = {}
var current_player_profile: Dictionary = {}

func reset_for_new_game() -> void:
	rng.randomize()
	current_round = 0
	current_phase = "main_menu"
	auction_session = {}
	_seen_intro.clear()
	codex_item_ids.clear()
	city_visit_counts.clear()
	_build_players()
	_build_map()

func apply_player_profile(profile: Dictionary) -> void:
	current_player_profile = profile.duplicate(true)
	var human = human_player()
	if human == null:
		return
	human.display_name = str(profile.get("name", human.display_name))
	human.avatar_id = str(profile.get("avatar_id", human.avatar_id))
	human.color = profile.get("color", human.color)
	human.unspent_skill_points = int(profile.get("skill_points", human.unspent_skill_points))
	var skill_id := str(profile.get("initial_skill", ""))
	if skill_id != "" and can_unlock_skill(human, skill_id):
		unlock_skill(human.id, skill_id)

func has_seen_intro(type_key: String) -> bool:
	return _seen_intro.get(type_key, false)

func mark_intro_seen(type_key: String) -> void:
	_seen_intro[type_key] = true

func _build_players() -> void:
	players.clear()
	for i in range(GameConfig.PLAYER_COUNT):
		var p = PlayerModel.new()
		p.id = i
		p.display_name = GameConfig.PLAYER_NAMES[i]
		p.is_ai = (i != GameConfig.HUMAN_PLAYER_ID)
		p.color = GameConfig.PLAYER_COLORS[i]
		p.money = GameConfig.START_MONEY
		p.position = 0
		p.inventory = []
		p.ready = false
		p.avatar_id = GameConfig.PLAYER_AVATARS[i] if i < GameConfig.PLAYER_AVATARS.size() else "collector_gold"
		p.history_fragments = 0
		p.level = 1
		p.unspent_skill_points = 0
		p.attributes = GameConfig.DEFAULT_ATTRIBUTES.duplicate(true)
		p.skills = {}
		p.tools = _initial_tools_for(p)
		players.append(p)

func _initial_tools_for(player) -> Dictionary:
	var tools := GameConfig.DEFAULT_TOOLS.duplicate(true)
	var loadout_key := str(player.avatar_id)
	if player.is_ai:
		loadout_key = "ai_li" if player.id == 1 else "ai_lu"
	var loadout: Dictionary = GameConfig.INITIAL_TOOL_LOADOUTS.get(loadout_key, {})
	for tool_id in loadout.keys():
		tools[tool_id] = int(tools.get(tool_id, 0)) + int(loadout[tool_id])
	return tools

func to_save_dict() -> Dictionary:
	var player_data: Array = []
	for p in players:
		var inv: Array = []
		for inst in p.inventory:
			if inst != null and inst.has_method("to_save_dict"):
				inv.append(inst.to_save_dict())
		player_data.append({
			"id": p.id,
			"display_name": p.display_name,
			"is_ai": p.is_ai,
			"color": p.color.to_html(),
			"money": p.money,
			"position": p.position,
			"inventory": inv,
			"ready": p.ready,
			"avatar_id": p.avatar_id,
			"history_fragments": p.history_fragments,
			"level": p.level,
			"unspent_skill_points": p.unspent_skill_points,
			"attributes": p.attributes,
			"skills": p.skills,
			"tools": p.tools,
		})
	return {
		"version": 1,
		"current_round": current_round,
		"current_phase": current_phase,
		"players": player_data,
		"codex_item_ids": codex_item_ids,
		"city_visit_counts": city_visit_counts,
		"seen_intro": _seen_intro,
		"profile": current_player_profile,
	}

func load_from_save_dict(data: Dictionary) -> void:
	current_round = int(data.get("current_round", 0))
	current_phase = str(data.get("current_phase", "round_begin"))
	auction_session = {}
	_seen_intro = data.get("seen_intro", {}).duplicate(true)
	codex_item_ids = data.get("codex_item_ids", {}).duplicate(true)
	city_visit_counts = data.get("city_visit_counts", {}).duplicate(true)
	current_player_profile = data.get("profile", {}).duplicate(true)
	_build_map()
	players.clear()
	for pdata in data.get("players", []):
		var p = PlayerModel.new()
		p.id = int(pdata.get("id", 0))
		p.display_name = str(pdata.get("display_name", "玩家"))
		p.is_ai = bool(pdata.get("is_ai", false))
		p.color = Color(str(pdata.get("color", "ffffff")))
		p.money = int(pdata.get("money", GameConfig.START_MONEY))
		p.position = int(pdata.get("position", 0))
		p.ready = false
		p.avatar_id = str(pdata.get("avatar_id", "collector_gold"))
		p.history_fragments = int(pdata.get("history_fragments", 0))
		p.level = int(pdata.get("level", level_for_fragments(p.history_fragments)))
		p.unspent_skill_points = int(pdata.get("unspent_skill_points", 0))
		p.attributes = pdata.get("attributes", GameConfig.DEFAULT_ATTRIBUTES).duplicate(true)
		p.skills = pdata.get("skills", {}).duplicate(true)
		p.tools = _normalize_tools(pdata.get("tools", GameConfig.DEFAULT_TOOLS))
		p.inventory = []
		for inst_data in pdata.get("inventory", []):
			var item_def = ItemsDBRef.item_by_id(str(inst_data.get("item_id", "")))
			if item_def == null:
				continue
			var inst := ItemInstanceModel.new()
			inst.setup_from_save_dict(inst_data, item_def)
			p.inventory.append(inst)
		players.append(p)

func _normalize_tools(raw_tools) -> Dictionary:
	var tools := GameConfig.DEFAULT_TOOLS.duplicate(true)
	if typeof(raw_tools) == TYPE_DICTIONARY:
		for tool_id in raw_tools.keys():
			if tools.has(tool_id):
				tools[tool_id] = max(0, int(raw_tools[tool_id]))
	return tools

func tool_count(player_id: int, tool_id: String) -> int:
	var p = get_player(player_id)
	if p == null:
		return 0
	return int(p.tools.get(tool_id, 0))

func add_tool(player_id: int, tool_id: String, amount: int = 1) -> bool:
	var p = get_player(player_id)
	if p == null or amount <= 0:
		return false
	if not p.tools.has(tool_id):
		p.tools[tool_id] = 0
	p.tools[tool_id] = int(p.tools.get(tool_id, 0)) + amount
	return true

func consume_tool(player_id: int, tool_id: String, amount: int = 1) -> bool:
	var p = get_player(player_id)
	if p == null or amount <= 0:
		return false
	var current := int(p.tools.get(tool_id, 0))
	if current < amount:
		return false
	p.tools[tool_id] = current - amount
	EventBus.tool_used.emit(player_id, tool_id)
	return true

func _build_map() -> void:
	map_tiles.clear()
	var layout: Array = MapLayoutData.build_default_layout()
	for i in range(layout.size()):
		var t = MapTileModel.new()
		var entry: Dictionary = layout[i]
		t.index = i
		t.type = entry.get("type", MapTileModel.Type.CITY)
		t.display_name = entry.get("name", "未名")
		t.lat = float(entry.get("lat", 33.0))
		t.lng = float(entry.get("lng", 110.0))
		t.norm_pos = MapLayoutData.project_geo_to_norm(t.lng, t.lat)
		t.country = entry.get("country", "")
		t.label_offset = entry.get("label_offset", Vector2.ZERO)
		t.ohm_source = entry.get("ohm_source", "")
		map_tiles.append(t)

func get_player(id: int):
	for p in players:
		if p.id == id:
			return p
	return null

func human_player():
	return get_player(GameConfig.HUMAN_PLAYER_ID)

func reset_ready_flags() -> void:
	for p in players:
		p.ready = false
		EventBus.player_ready_changed.emit(p.id, false, current_phase)

func mark_player_ready(player_id: int) -> void:
	var p = get_player(player_id)
	if p == null or p.ready:
		return
	p.ready = true
	if GameConfig.DEBUG_AUTOPLAY:
		print("[state] p%d ready (phase=%s)" % [p.id, current_phase])
	EventBus.player_ready_changed.emit(p.id, true, current_phase)
	if all_ready():
		if GameConfig.DEBUG_AUTOPLAY:
			print("[state] all_players_ready phase=%s" % current_phase)
		EventBus.all_players_ready.emit(current_phase)

func all_ready() -> bool:
	for p in players:
		if not p.ready:
			return false
	return true

func is_auction_round(round_num: int) -> bool:
	return GameConfig.AUCTION_ROUNDS.has(round_num)

func change_money(player_id: int, delta: int, reason: String = "") -> bool:
	var p = get_player(player_id)
	if p == null:
		return false
	if p.money + delta < 0:
		return false
	p.money += delta
	EventBus.money_changed.emit(p.id, p.money)
	if delta != 0:
		EventBus.money_delta.emit(p.id, delta, reason)
	return true

func city_visit_count(tile_index: int) -> int:
	return int(city_visit_counts.get(tile_index, 0))

func mark_city_visited(tile_index: int) -> void:
	city_visit_counts[tile_index] = city_visit_count(tile_index) + 1

func add_item_to_player(player_id: int, instance) -> void:
	var p = get_player(player_id)
	if p == null:
		return
	p.inventory.append(instance)
	EventBus.item_acquired.emit(p.id, instance)
	_award_item_history(p, instance)

func tile_at(index: int):
	if map_tiles.is_empty():
		return null
	var n = map_tiles.size()
	return map_tiles[((index % n) + n) % n]

func ranking_data() -> Array:
	# 返回 [{player_id, name, money, inv_value, total}]
	var result: Array = []
	for p in players:
		var inv_value: int = inventory_value(p)
		result.append({
			"player_id": p.id,
			"name": p.display_name,
			"money": p.money,
			"inv_value": inv_value,
			"total": p.money + inv_value,
			"color": p.color,
			"items": p.inventory.size(),
			"level": p.level,
			"title": title_for_level(p.level),
		})
	result.sort_custom(func(a, b): return a["total"] > b["total"])
	return result

func level_for_fragments(fragments: int) -> int:
	var lvl := 1
	for row in GameConfig.HISTORY_LEVELS:
		if fragments >= int(row.get("fragments", 0)):
			lvl = int(row.get("level", 1))
	return lvl

func title_for_level(level: int) -> String:
	var title := "初入行"
	for row in GameConfig.HISTORY_LEVELS:
		if int(row.get("level", 1)) <= level:
			title = str(row.get("title", title))
	return title

func next_level_threshold(level: int) -> int:
	for row in GameConfig.HISTORY_LEVELS:
		if int(row.get("level", 1)) > level:
			return int(row.get("fragments", 0))
	return int(GameConfig.HISTORY_LEVELS.back().get("fragments", 5000))

func current_level_threshold(level: int) -> int:
	var threshold := 0
	for row in GameConfig.HISTORY_LEVELS:
		if int(row.get("level", 1)) <= level:
			threshold = int(row.get("fragments", 0))
	return threshold

func add_history_fragments(player_id: int, amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var p = get_player(player_id)
	if p == null:
		return
	var old_level: int = p.level
	p.history_fragments += amount
	p.level = level_for_fragments(p.history_fragments)
	if p.level > old_level:
		var gained_points: int = p.level - old_level
		if old_level < 5 and p.level >= 5:
			gained_points += 1
		if old_level < 10 and p.level >= 10:
			gained_points += 1
		p.unspent_skill_points += gained_points
		EventBus.player_leveled_up.emit(p.id, p.level)
		EventBus.toast.emit("%s 升至 Lv.%d · %s" % [p.display_name, p.level, title_for_level(p.level)], "good")
	EventBus.history_fragments_changed.emit(p.id, p.history_fragments, amount, reason)

func unlock_codex_for_item(item_id: String) -> bool:
	if item_id == "":
		return false
	if codex_item_ids.has(item_id):
		return false
	codex_item_ids[item_id] = true
	EventBus.codex_unlocked.emit(item_id)
	return true

func skill_def(skill_id: String) -> Dictionary:
	for s in GameConfig.SKILL_TREE:
		if str(s.get("id", "")) == skill_id:
			return s
	return {}

func can_unlock_skill(player, skill_id: String) -> bool:
	if player == null or player.skills.get(skill_id, false):
		return false
	var def := skill_def(skill_id)
	if def.is_empty():
		return false
	if player.unspent_skill_points < int(def.get("cost", 1)):
		return false
	for req in def.get("requires", []):
		if not player.skills.get(str(req), false):
			return false
	return true

func unlock_skill(player_id: int, skill_id: String) -> bool:
	var p = get_player(player_id)
	if not can_unlock_skill(p, skill_id):
		return false
	var def := skill_def(skill_id)
	p.unspent_skill_points -= int(def.get("cost", 1))
	p.skills[skill_id] = true
	match skill_id:
		"dating_basics":
			p.attributes["appraisal"] = int(p.attributes.get("appraisal", 1)) + 1
	EventBus.skill_unlocked.emit(player_id, skill_id)
	EventBus.toast.emit("习得技能：%s" % str(def.get("name", skill_id)), "good")
	return true

func inventory_capacity(player) -> int:
	if player == null:
		return GameConfig.START_INVENTORY_CAPACITY
	var cap: int = GameConfig.START_INVENTORY_CAPACITY + int(player.attributes.get("capacity", 1)) * 2
	if player.skills.get("pack_order", false):
		cap += 3
	return cap

func inventory_value(player) -> int:
	if player == null:
		return 0
	var total := 0.0
	for inst in player.inventory:
		total += float(inst.estimated_value)
	if player.skills.get("collector_heart", false):
		total *= 1.05
	return int(round(total))

func total_assets(player) -> int:
	if player == null:
		return 0
	return player.money + inventory_value(player)

func _award_item_history(player, instance) -> void:
	if instance == null or instance.def == null:
		return
	var rarity: int = instance.rarity()
	var amount: int = 10 + rarity * 8 + int(round(sqrt(float(max(1, instance.real_price))) * 2.0))
	if instance.is_fake:
		amount = max(1, int(round(float(amount) * 0.4)))
	var first_codex := false
	if player.id == GameConfig.HUMAN_PLAYER_ID:
		first_codex = unlock_codex_for_item(instance.def.id)
	if first_codex:
		var bonus: int = 20 + rarity * 12
		if player.skills.get("catalog_notes", false):
			bonus = int(round(float(bonus) * 1.25))
		amount += bonus
	add_history_fragments(player.id, amount, "收藏 %s" % instance.display_name())
