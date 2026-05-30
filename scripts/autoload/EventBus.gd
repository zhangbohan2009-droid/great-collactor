extends Node
## 全局信号总线
## 解耦 UI 与逻辑：所有跨模块通信都走这里

# === 回合 / 流程 ===
signal phase_changed(phase: String)            # 阶段切换
signal round_started(round_num: int)           # 新回合开始
signal round_ended(round_num: int)             # 回合结算后
signal game_started()
signal game_finished()

# === 玩家就绪（同时行动的核心） ===
signal player_ready_changed(player_id: int, ready: bool, phase: String)
signal all_players_ready(phase: String)

# === 掷骰 / 移动 ===
signal dice_rolled(player_id: int, value: int)
signal dice_phase_resolved(results: Dictionary)
signal player_moved(player_id: int, from_index: int, to_index: int)
signal player_arrived(player_id: int, tile_index: int)

# === 事件 / 弹窗 ===
signal tile_event_started(player_id: int, tile_index: int)
signal tile_event_finished(player_id: int, tile_index: int)
signal dialog_request(dialog_type: String, payload: Dictionary)
signal dialog_closed(dialog_type: String)

# === 经济 ===
signal money_changed(player_id: int, new_amount: int)
signal money_delta(player_id: int, delta: int, reason: String)
signal item_acquired(player_id: int, item_instance)        # ItemInstance
signal history_fragments_changed(player_id: int, total: int, gained: int, reason: String)
signal player_leveled_up(player_id: int, new_level: int)
signal skill_unlocked(player_id: int, skill_id: String)
signal tool_used(player_id: int, tool_id: String)
signal codex_unlocked(item_id: String)

# === 拍卖 ===
signal auction_started(session_data: Dictionary)
signal auction_lot_started(lot_index: int, lot_data: Dictionary)
signal auction_bid_placed(bidder_id: int, amount: int)
signal auction_lot_finished(lot_index: int, winner_id: int, final_price: int)
signal auction_finished()

# === HUD 提示 ===
signal toast(text: String, tone: String)
