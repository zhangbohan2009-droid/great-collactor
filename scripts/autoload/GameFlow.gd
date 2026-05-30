extends Node
## 主流程状态机
## RoundBegin → DicePhase → MovePhase → EventPhase → (Auction 在拍卖回合) → RoundEnd → 下回合 / Ranking
## 所有 phase 都用 await EventBus.all_players_ready 推进

const DiceSystemRef := preload("res://scripts/systems/DiceSystem.gd")
const MarketSystemRef := preload("res://scripts/systems/MarketSystem.gd")
const AISystemRef := preload("res://scripts/systems/AISystem.gd")
const AuctionSystemRef := preload("res://scripts/systems/AuctionSystem.gd")
const MapTileModel := preload("res://scripts/models/MapTile.gd")

var _running: bool = false
var _last_dice_values: Dictionary = {}    # player_id -> dice value
var _dice_mods: Dictionary = {}           # player_id -> { tool_id, forced_roll, max_roll, bonus_steps, direction }
var _pending_tile_events: Dictionary = {} # player_id -> tile_index
var _city_stocks: Dictionary = {}         # tile_index -> Array[ItemInstance]（拍卖回合刷新）
var _bm_stocks: Dictionary = {}
var _city_offers: Dictionary = {}

func _ready() -> void:
	EventBus.player_ready_changed.connect(_on_ready_changed)

## 同步准备：初始化玩家/地图。UI 在它之后创建才能看到 GameState.players
func prepare_new_game(profile: Dictionary = {}) -> void:
	GameState.reset_for_new_game()
	if not profile.is_empty():
		GameState.apply_player_profile(profile)
	_city_stocks.clear()
	_bm_stocks.clear()
	_city_offers.clear()

## 启动新一局（异步主循环）
func start_new_game() -> void:
	if _running:
		return
	_running = true
	EventBus.game_started.emit()
	_set_phase("round_begin")
	SaveSystem.save_game()
	# 给主菜单和场景一个切换时间
	await get_tree().create_timer(0.1).timeout
	_run_main_loop()

func resume_game() -> void:
	if _running:
		return
	_running = true
	EventBus.game_started.emit()
	_set_phase("round_begin")
	await get_tree().create_timer(0.1).timeout
	_run_main_loop()

func _set_phase(phase: String) -> void:
	GameState.current_phase = phase
	if GameConfig.DEBUG_AUTOPLAY:
		print("[flow] phase=%s round=%d" % [phase, GameState.current_round])
	EventBus.phase_changed.emit(phase)

func _run_main_loop() -> void:
	while _running and GameState.current_round < GameConfig.MAX_ROUNDS:
		GameState.current_round += 1
		var round_num: int = GameState.current_round
		_set_phase("round_begin")
		EventBus.round_started.emit(round_num)
		EventBus.toast.emit("第 %d 回合" % round_num, "info")
		await get_tree().create_timer(0.4).timeout

		# 非拍卖回合：掷骰 → 移动 → 格子事件
		await _phase_dice()
		await _phase_move()
		await _phase_event()

		# 若本回合是拍卖回合：先走完移动事件，再进入拍卖
		if GameState.is_auction_round(round_num):
			await _phase_auction(round_num)

		_set_phase("round_end")
		EventBus.round_ended.emit(round_num)
		await get_tree().create_timer(0.3).timeout

	_set_phase("ranking")
	EventBus.game_finished.emit()
	_running = false

# -----------------------------------------------------
# Dice
# -----------------------------------------------------
func _phase_dice() -> void:
	_set_phase("dice")
	_last_dice_values.clear()
	_dice_mods.clear()
	# 新回合刷新各城/黑市库存
	_city_stocks.clear()
	_bm_stocks.clear()
	_city_offers.clear()
	GameState.reset_ready_flags()
	# 给真人 UI 留空间，AI 延迟掷骰
	for p in GameState.players:
		if p.is_ai:
			_ai_roll_async(p)
	if GameConfig.DEBUG_AUTOPLAY:
		_autoplay_roll_human()
	await EventBus.all_players_ready
	EventBus.dice_phase_resolved.emit(_last_dice_values.duplicate(true))

func _ai_roll_async(player) -> void:
	await get_tree().create_timer(randf_range(0.6, 1.2)).timeout
	if not _running:
		return
	var choice: Dictionary = AISystemRef.choose_dice_tool(player, GameState.map_tiles, GameState.rng)
	if not choice.is_empty():
		use_dice_tool(player.id, str(choice.get("id", "")), choice.get("payload", {}))
	roll_dice_for(player.id)

# 调试用：真人在 AUTOPLAY 模式下也自动掷骰
func _autoplay_roll_human() -> void:
	await get_tree().create_timer(randf_range(0.6, 1.2)).timeout
	if not _running:
		return
	roll_dice_for(GameConfig.HUMAN_PLAYER_ID)

## 玩家或 AI 触发掷骰
func roll_dice_for(player_id: int) -> void:
	var p = GameState.get_player(player_id)
	if p == null or p.ready:
		return
	if GameState.current_phase != "dice":
		return
	var mod: Dictionary = _dice_mods.get(player_id, {})
	var v: int = int(mod.get("forced_roll", 0))
	if v <= 0:
		if mod.has("max_roll"):
			v = GameState.rng.randi_range(GameConfig.DICE_MIN, int(mod.get("max_roll", GameConfig.DICE_MAX)))
		else:
			v = DiceSystemRef.roll(GameState.rng)
	v = min(GameConfig.DICE_MAX, v + int(mod.get("bonus_steps", 0)))
	_last_dice_values[player_id] = v
	EventBus.dice_rolled.emit(player_id, v)
	GameState.mark_player_ready(player_id)

func can_use_dice_tool(player_id: int, tool_id: String) -> bool:
	if GameState.current_phase != "dice":
		return false
	var p = GameState.get_player(player_id)
	if p == null or p.ready:
		return false
	if not GameConfig.MOVEMENT_TOOL_IDS.has(tool_id):
		return false
	if _dice_mods.has(player_id):
		return false
	return GameState.tool_count(player_id, tool_id) > 0

func use_dice_tool(player_id: int, tool_id: String, payload: Dictionary = {}) -> bool:
	if not can_use_dice_tool(player_id, tool_id):
		return false
	var mod := { "tool_id": tool_id, "direction": 1 }
	match tool_id:
		"fixed_dice_card":
			var value := clampi(int(payload.get("value", 1)), GameConfig.DICE_MIN, GameConfig.DICE_MAX)
			mod["forced_roll"] = value
		"reverse_card":
			mod["direction"] = -1
		"small_step_card":
			mod["max_roll"] = 3
		"double_step_card":
			mod["bonus_steps"] = 2
		_:
			return false
	if not GameState.consume_tool(player_id, tool_id):
		return false
	_dice_mods[player_id] = mod
	EventBus.toast.emit("%s 使用了%s" % [GameState.get_player(player_id).display_name, GameConfig.tool_name(tool_id)], "info")
	return true

func dice_tool_used(player_id: int) -> bool:
	return _dice_mods.has(player_id)

func get_last_move_direction(player_id: int) -> int:
	return int(_dice_mods.get(player_id, {}).get("direction", 1))

# -----------------------------------------------------
# Move（同时移动）
# -----------------------------------------------------
func _phase_move() -> void:
	_set_phase("move")
	GameState.reset_ready_flags()
	# 每个 player 都 fire move 事件，由 UI 用 tween 演出
	for p in GameState.players:
		var steps: int = int(_last_dice_values.get(p.id, 0))
		var from_index: int = p.position
		var direction := get_last_move_direction(p.id)
		var total_tiles: int = GameState.map_tiles.size() if not GameState.map_tiles.is_empty() else GameConfig.TOTAL_TILES
		var to_index: int = DiceSystemRef.target_index(from_index, steps, total_tiles, direction)
		p.position = to_index
		_pending_tile_events[p.id] = to_index
		EventBus.player_moved.emit(p.id, from_index, to_index)
	# UI 演完动画会调 mark_player_ready
	await EventBus.all_players_ready

	# 派发到达事件
	for p in GameState.players:
		EventBus.player_arrived.emit(p.id, p.position)

# -----------------------------------------------------
# Event（格子事件，每人各自处理）
# -----------------------------------------------------
func _phase_event() -> void:
	_set_phase("event")
	GameState.reset_ready_flags()
	# 真人：抛信号让 UI 弹窗
	# AI：本地完成决策后 mark_ready
	for p in GameState.players:
		var tile_index: int = int(_pending_tile_events.get(p.id, p.position))
		var tile = GameState.tile_at(tile_index)
		if tile == null:
			GameState.mark_player_ready(p.id)
			continue
		if tile.type == MapTileModel.Type.BLACK_MARKET and GameState.consume_tool(p.id, "safe_pass_card"):
			GameState.add_history_fragments(p.id, 25, "平安符避开 %s" % tile.display_name)
			EventBus.toast.emit("%s 用平安符避开了 %s" % [p.display_name, tile.display_name], "good")
			EventBus.tile_event_finished.emit(p.id, tile_index)
			GameState.mark_player_ready(p.id)
			continue
		EventBus.tile_event_started.emit(p.id, tile_index)
		if p.is_ai or (GameConfig.DEBUG_AUTOPLAY and p.id == GameConfig.HUMAN_PLAYER_ID):
			_ai_handle_tile_async(p, tile)
		elif p.id == GameConfig.HUMAN_PLAYER_ID:
			# 真人格子事件：让 MapView 收到 tile_event_started 后弹窗
			pass
	await EventBus.all_players_ready

func _ai_handle_tile_async(player, tile) -> void:
	await get_tree().create_timer(randf_range(0.6, 1.4)).timeout
	if not _running:
		return
	_ai_handle_tile_sync(player, tile)
	EventBus.tile_event_finished.emit(player.id, tile.index)
	GameState.mark_player_ready(player.id)

func _ai_handle_tile_sync(player, tile) -> void:
	match tile.type:
		MapTileModel.Type.CITY:
			var stock: Array = get_city_stock(tile.index)
			var pick = AISystemRef.choose_city_pick(player, stock, GameState.rng)
			if pick != null:
				var inst: Resource = pick["inst"]
				var ask: int = _discounted_price(player, int(pick["ask"]))
				if GameState.change_money(player.id, -ask):
					inst.paid_price = ask
					inst.acquired_round = GameState.current_round
					inst.acquired_from = tile.display_name
					stock.erase(inst)
					_city_stocks[tile.index] = stock
					GameState.add_item_to_player(player.id, inst)
					EventBus.toast.emit("%s 在 %s 买入 %s（%d 两）" % [player.display_name, tile.display_name, inst.display_name(), ask], "info")
			GameState.mark_city_visited(tile.index)
		MapTileModel.Type.BLACK_MARKET:
			var stock2: Array = get_bm_stock(tile.index)
			var pick2 = AISystemRef.choose_black_market_pick(player, stock2, GameState.rng)
			if pick2 != null:
				var inst2: Resource = pick2["inst"]
				var ask2: int = _discounted_price(player, int(pick2["ask"]))
				if GameState.change_money(player.id, -ask2):
					inst2.paid_price = ask2
					inst2.acquired_round = GameState.current_round
					inst2.acquired_from = tile.display_name
					stock2.erase(inst2)
					_bm_stocks[tile.index] = stock2
					GameState.add_item_to_player(player.id, inst2)
					EventBus.toast.emit("%s 摸进 %s（%d 两）" % [player.display_name, tile.display_name, ask2], "warn")
		MapTileModel.Type.SCENIC:
			GameState.add_history_fragments(player.id, _scenic_reward(player), "游历 %s" % tile.display_name)
			EventBus.toast.emit("%s 路过 %s" % [player.display_name, tile.display_name], "muted")
		MapTileModel.Type.TEMPLE:
			GameState.add_history_fragments(player.id, _temple_reward(player), "参访 %s" % tile.display_name)
			EventBus.toast.emit("%s 在 %s 拜了一拜" % [player.display_name, tile.display_name], "muted")
		MapTileModel.Type.GAMBLING:
			_ai_gamble(player, tile)

# 由真人 UI 关闭弹窗时调用
func human_finish_tile_event() -> void:
	if GameState.current_phase != "event":
		return
	var human = GameState.human_player()
	if human == null or human.ready:
		return
	var tile = GameState.tile_at(human.position)
	if tile != null:
		match tile.type:
			MapTileModel.Type.CITY:
				GameState.mark_city_visited(tile.index)
			MapTileModel.Type.SCENIC:
				GameState.add_history_fragments(human.id, _scenic_reward(human), "游历 %s" % tile.display_name)
			MapTileModel.Type.TEMPLE:
				GameState.add_history_fragments(human.id, _temple_reward(human), "参访 %s" % tile.display_name)
	EventBus.tile_event_finished.emit(human.id, human.position)
	GameState.mark_player_ready(human.id)

func _ai_gamble(player, tile) -> void:
	var wager: int = 20 if player.money < 140 else 50
	if player.money < wager:
		EventBus.toast.emit("%s 路过 %s，没敢入局" % [player.display_name, tile.display_name], "muted")
		return
	var player_roll: int = GameState.rng.randi_range(1, 6)
	var house_roll: int = GameState.rng.randi_range(1, 6)
	if player_roll > house_roll:
		GameState.change_money(player.id, wager, "临淄闹市赌坊")
		EventBus.toast.emit("%s 在 %s 赢了 %d 两" % [player.display_name, tile.display_name, wager], "good")
	elif player_roll < house_roll:
		GameState.change_money(player.id, -wager, "临淄闹市赌坊")
		EventBus.toast.emit("%s 在 %s 输了 %d 两" % [player.display_name, tile.display_name, wager], "warn")
	else:
		EventBus.toast.emit("%s 在 %s 平局退筹" % [player.display_name, tile.display_name], "muted")

func _scenic_reward(player) -> int:
	var amount: int = 45 + GameState.current_round * 4
	amount = int(round(float(amount) * (1.0 + float(player.attributes.get("fortune", 1)) * 0.03)))
	if player.skills.get("mountain_search", false):
		amount = int(round(float(amount) * 1.2))
	return amount

func _temple_reward(player) -> int:
	var amount: int = 35 + int(player.level) * 5
	amount = int(round(float(amount) * (1.0 + float(player.attributes.get("fortune", 1)) * 0.03)))
	return amount

# -----------------------------------------------------
# 城市 / 黑市 库存懒加载（每个 tile 缓存一份本回合的 stock）
# -----------------------------------------------------
func get_city_stock(tile_index: int) -> Array:
	if not _city_stocks.has(tile_index) or _city_stocks[tile_index].size() == 0:
		var tile: Resource = GameState.tile_at(tile_index)
		_city_stocks[tile_index] = MarketSystemRef.roll_city_stock(GameState.rng, tile.country if tile != null else "")
	return _city_stocks[tile_index]

func get_city_offers(tile_index: int) -> Array:
	if not _city_offers.has(tile_index) or _city_offers[tile_index].size() == 0:
		var tile: Resource = GameState.tile_at(tile_index)
		var visit_bonus: int = max(GameState.city_visit_count(tile_index), GameState.region_visit_count_for_tile(tile))
		_city_offers[tile_index] = MarketSystemRef.roll_city_offers(GameState.rng, GameState.human_player(), visit_bonus, tile.country if tile != null else "")
	return _city_offers[tile_index]

func get_bm_stock(tile_index: int) -> Array:
	if not _bm_stocks.has(tile_index) or _bm_stocks[tile_index].size() == 0:
		var tile: Resource = GameState.tile_at(tile_index)
		_bm_stocks[tile_index] = MarketSystemRef.roll_black_market_stock(GameState.rng, tile.country if tile != null else "")
	return _bm_stocks[tile_index]

## 真人购买（CityDialog 内调用）；成功返回 true
func human_buy_item(tile_index: int, inst: Resource, price: int) -> bool:
	var human = GameState.human_player()
	if human == null:
		return false
	if human.inventory.size() >= GameState.inventory_capacity(human):
		EventBus.toast.emit("库容已满，先整理背包", "warn")
		return false
	var final_price := _discounted_price(human, price)
	if not GameState.change_money(human.id, -final_price, "买入 %s" % inst.display_name()):
		return false
	var stock: Array
	var tile = GameState.tile_at(tile_index)
	if tile.type == MapTileModel.Type.BLACK_MARKET:
		stock = get_bm_stock(tile_index)
	else:
		stock = get_city_stock(tile_index)
	stock.erase(inst)
	inst.paid_price = final_price
	inst.acquired_round = GameState.current_round
	inst.acquired_from = tile.display_name
	GameState.add_item_to_player(human.id, inst)
	EventBus.toast.emit("你以 %d 两买入 %s" % [final_price, inst.display_name()], "good")
	return true

func _discounted_price(player, price: int) -> int:
	if player != null and GameState.tool_count(player.id, "appraisal_coupon") > 0:
		if GameState.consume_tool(player.id, "appraisal_coupon"):
			var discounted: int = max(1, price - 30)
			EventBus.toast.emit("%s 使用鉴定券，省下 %d 两" % [player.display_name, price - discounted], "good")
			return discounted
	return price

func human_buy_city_offer(tile_index: int, offer: Dictionary) -> bool:
	var inst: Resource = offer.get("inst", null)
	var price := int(offer.get("ask_price", 0))
	if inst == null or price <= 0:
		return false
	if not human_buy_item(tile_index, inst, price):
		return false
	var offers := get_city_offers(tile_index)
	offers.erase(offer)
	_city_offers[tile_index] = offers
	return true

func human_sell_city_offer(tile_index: int, offer: Dictionary) -> bool:
	var human = GameState.human_player()
	if human == null:
		return false
	var inst = offer.get("target_inst", null)
	var price := int(offer.get("offer_price", 0))
	if inst == null or price <= 0:
		return false
	if not human.inventory.has(inst):
		EventBus.toast.emit("这件货已不在库中", "warn")
		return false
	human.inventory.erase(inst)
	GameState.change_money(human.id, price, "卖出 %s" % inst.display_name())
	var offers := get_city_offers(tile_index)
	offers.erase(offer)
	_city_offers[tile_index] = offers
	EventBus.toast.emit("你以 %d 两售出 %s" % [price, inst.display_name()], "good")
	return true

# -----------------------------------------------------
# Auction
# -----------------------------------------------------
func _phase_auction(round_num: int) -> void:
	_set_phase("auction")
	EventBus.toast.emit("第 %d 回合拍卖会开始" % round_num, "good")
	await get_tree().create_timer(0.6).timeout
	GameState.auction_session = AuctionSystemRef.create_session(round_num, GameState.rng)
	_apply_auction_hints()
	EventBus.auction_started.emit(GameState.auction_session)
	# 等 AuctionScreen 处理完发回信号
	await EventBus.auction_finished
	GameState.auction_session = {}

## 当本场拍卖结束时由 AuctionScreen 调
func notify_auction_finished() -> void:
	EventBus.auction_finished.emit()

func _apply_auction_hints() -> void:
	for p in GameState.players:
		if GameState.tool_count(p.id, "auction_hint_card") <= 0:
			continue
		if not GameState.consume_tool(p.id, "auction_hint_card"):
			continue
		var lots: Array = GameState.auction_session.get("lots", [])
		if lots.is_empty():
			continue
		var lot: Dictionary = lots[0]
		var inst = lot.get("instance", null)
		if inst != null:
			EventBus.toast.emit("%s 获得拍讯：首件拍品约 %d-%d 两" % [p.display_name, int(inst.appraised_low), int(inst.appraised_high)], "info")

# -----------------------------------------------------
# Ready 状态聚合
# -----------------------------------------------------
func _on_ready_changed(_id: int, _ready: bool, _phase: String) -> void:
	pass

func abort() -> void:
	_running = false
