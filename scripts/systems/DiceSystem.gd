extends RefCounted
class_name DiceSystem
## 掷骰子工具

static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(GameConfig.DICE_MIN, GameConfig.DICE_MAX)

## 计算从 from_index 走 steps 步后的目标格子 index（环形）
static func target_index(from_index: int, steps: int, total: int) -> int:
	return (from_index + steps) % total

## 返回经过的路径（含起点、含终点）
static func walk_path(from_index: int, steps: int, total: int) -> Array[int]:
	var path: Array[int] = []
	path.append(from_index)
	for i in range(1, steps + 1):
		path.append((from_index + i) % total)
	return path
