extends Node

# -------------------------------------------------------
# GameData — 全局存档单例（Autoload）
# 保存路径：user://save_data.json
# -------------------------------------------------------

const SAVE_PATH = "user://save_data.json"

# 跨局持久数据
var currency: int = 0
var museum_collection: Dictionary = {}
var items: Dictionary = {
	"spare_brush": 0,   # 备用软刷
}
# 文物定义（10件：5C+3F+1R+1L）
const ARTIFACT_DEFS = {
	# Common (稀有度 1) × 5
	"pottery":     { "name": "陶片",     "rarity": 1, "image": "" },
	"adze":        { "name": "石锛",     "rarity": 1, "image": "" },
	"awl":         { "name": "骨锥",     "rarity": 1, "image": "" },
	"shell":       { "name": "贝饰",     "rarity": 1, "image": "" },
	"coin":        { "name": "铜钱",     "rarity": 1, "image": "" },
	# Fine (稀有度 2) × 3
	"jade":        { "name": "玉璧",     "rarity": 2, "image": "" },
	"painted_pot": { "name": "彩陶壶",   "rarity": 2, "image": "" },
	"mirror":      { "name": "铜镜",     "rarity": 2, "image": "" },
	# Rare (稀有度 3) × 1
	"mask":        { "name": "青铜面具", "rarity": 3, "image": "" },
	# Legendary (稀有度 4) × 1
	"tree":        { "name": "青铜神树", "rarity": 4, "image": "" },
}

# 道具定义（价格、每局使用上限、显示名）
const ITEM_DEFS = {
	"spare_brush": {
		"name":       "备用软刷",
		"price":      1000,
		"run_limit":  1,     # 当前地图每局最多使用次数
		"desc":       "+1 刷子（每局限用 1 次）",
	},
}

func _ready():
	load_data()

# -------------------------------------------------------
# 公开接口
# -------------------------------------------------------

func add_currency(amount: int):
	currency += amount
	save_data()

func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	save_data()
	return true

func buy_item(item_id: String) -> bool:
	if not ITEM_DEFS.has(item_id):
		return false
	var price = ITEM_DEFS[item_id]["price"]
	if not spend_currency(price):
		return false
	items[item_id] = items.get(item_id, 0) + 1
	save_data()
	return true

func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)

func consume_item(item_id: String) -> bool:
	var count = items.get(item_id, 0)
	if count <= 0:
		return false
	items[item_id] = count - 1
	save_data()
	return true

func record_artifacts(artifact_list: Array):
	# artifact_list: Array of { id: String, damaged: bool }
	for artifact in artifact_list:
		var id = artifact.get("id", "")
		if id == "" or not ARTIFACT_DEFS.has(id):
			continue
		if not museum_collection.has(id):
			museum_collection[id] = { "found": 0, "intact": 0 }
		museum_collection[id]["found"] += 1
		if not artifact["damaged"]:
			museum_collection[id]["intact"] += 1
	save_data()

# -------------------------------------------------------
# 存档 / 读档
# -------------------------------------------------------

func save_data():
	var data = {
		"currency":          currency,
		"museum_collection": museum_collection,
		"items":             items,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_data():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		currency          = parsed.get("currency", 0)
		museum_collection = parsed.get("museum_collection", {})
		var saved_items   = parsed.get("items", {})
		for key in items.keys():
			items[key] = saved_items.get(key, 0)

func reset_data():
	currency          = 0
	museum_collection = {}
	for key in items.keys():
		items[key] = 0
	save_data()
