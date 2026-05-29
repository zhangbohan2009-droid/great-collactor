extends RefCounted
class_name RankingSystem
## 终局排名（资产 = 现金 + 库存估值）

static func compute() -> Array:
	return GameState.ranking_data()

static func title_for_rank(rank: int) -> String:
	match rank:
		1: return "万古传奇"
		2: return "名动天下"
		3: return "小有名气"
		_: return "碌碌一生"
