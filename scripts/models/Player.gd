class_name Player
extends Resource
## 玩家数据（真人 or AI）

@export var id: int = 0
@export var display_name: String = ""
@export var is_ai: bool = false
@export var color: Color = Color.WHITE
@export var money: int = 0
@export var position: int = 0
@export var inventory: Array = []              # Array[ItemInstance]
@export var ready: bool = false
@export var avatar_id: String = "collector_gold"
@export var history_fragments: int = 0
@export var level: int = 1
@export var unspent_skill_points: int = 0
@export var attributes: Dictionary = {}
@export var skills: Dictionary = {}
@export var tools: Dictionary = {}

func add_money(amount: int) -> void:
	money += amount

func can_afford(amount: int) -> bool:
	return money >= amount

func has_skill(skill_id: String) -> bool:
	return skills.get(skill_id, false)
