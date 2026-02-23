extends Node2D

# 地图参数
const COLS = 10
const ROWS = 7
const ARTIFACT_COUNT = 8
const BRUSH_INITIAL = 6

# 各稀有度的分数（完整 / 损坏）
const SCORE_INTACT  = { 1: 10,  2: 30,  3: 100, 4: 300 }
const SCORE_DAMAGED = { 1:  5,  2: 15,  3:  50, 4: 150 }

const CellScene = preload("res://scenes/cell.tscn")

var cells: Array = []         # cells[row][col] -> Cell
var cell_pos: Dictionary = {} # Cell -> Vector2i(row, col)
var brush_count: int = BRUSH_INITIAL
var score: int = 0
var map_generated: bool = false  # 第一次点击前地图尚未生成

@onready var grid_container = $VBoxContainer/GridContainer
@onready var brush_label    = $VBoxContainer/UI/BrushLabel
@onready var score_label    = $VBoxContainer/UI/ScoreLabel

func _ready():
	generate_grid()
	update_ui()

# -------------------------------------------------------
# 地图生成
# -------------------------------------------------------

func generate_grid():
	# 只创建格子和连接信号，文物等第一次点击后再生成
	cells = []
	for row in ROWS:
		cells.append([])
		for col in COLS:
			var cell = CellScene.instantiate()
			grid_container.add_child(cell)
			cells[row].append(cell)
			cell_pos[cell] = Vector2i(row, col)
			cell.requested_dig.connect(_on_cell_requested_dig)
			cell.requested_brush.connect(_on_cell_requested_brush)

func generate_map_avoiding(excluded_cell):
	# 第一次点击时调用，排除点击格子后生成文物和数字
	map_generated = true
	var excluded_pos = cell_pos[excluded_cell]
	var excluded_idx = excluded_pos.x * COLS + excluded_pos.y
	place_artifacts(excluded_idx)
	calculate_numbers()

func place_artifacts(excluded_idx: int):
	# 排除：四个角落 + 第一次点击的格子
	var corners = [0, COLS - 1, (ROWS - 1) * COLS, ROWS * COLS - 1]

	# 非角落且非第一次点击的位置供 rare / legendary 使用
	var non_corner: Array = []
	for p in range(COLS * ROWS):
		if p not in corners and p != excluded_idx:
			non_corner.append(p)
	non_corner.shuffle()

	var rare_idx      = non_corner[0]
	var legendary_idx = non_corner[1]

	# 剩余位置供 common / fine 使用（排除第一次点击的格子）
	var remaining: Array = []
	for p in range(COLS * ROWS):
		if p != rare_idx and p != legendary_idx and p != excluded_idx:
			remaining.append(p)
	remaining.shuffle()

	# 放置 rare 和 legendary
	cells[rare_idx / COLS][rare_idx % COLS].is_artifact     = true
	cells[rare_idx / COLS][rare_idx % COLS].artifact_rarity = 3
	cells[legendary_idx / COLS][legendary_idx % COLS].is_artifact     = true
	cells[legendary_idx / COLS][legendary_idx % COLS].artifact_rarity = 4

	# 放置 4 个 common 和 2 个 fine
	var common_fine = [1, 1, 1, 1, 2, 2]
	common_fine.shuffle()
	for i in 6:
		var idx = remaining[i]
		cells[idx / COLS][idx % COLS].is_artifact     = true
		cells[idx / COLS][idx % COLS].artifact_rarity = common_fine[i]

func calculate_numbers():
	for row in ROWS:
		for col in COLS:
			var cell = cells[row][col]
			if cell.is_artifact:
				continue
			var exact      = count_adjacent_artifacts(row, col)
			var max_rarity = get_max_adjacent_rarity(row, col)
			var range      = get_fuzzy_range(exact, max_rarity)
			cell.number_min = range.x
			cell.number_max = range.y

func count_adjacent_artifacts(row: int, col: int) -> int:
	var count = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var r = row + dr
			var c = col + dc
			if r >= 0 and r < ROWS and c >= 0 and c < COLS:
				if cells[r][c].is_artifact:
					count += 1
	return count

func get_max_adjacent_rarity(row: int, col: int) -> int:
	var max_rarity = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var r = row + dr
			var c = col + dc
			if r >= 0 and r < ROWS and c >= 0 and c < COLS:
				if cells[r][c].is_artifact:
					max_rarity = max(max_rarity, cells[r][c].artifact_rarity)
	return max_rarity

func get_fuzzy_range(exact: int, max_rarity: int) -> Vector2i:
	# 没有相邻文物时永远精确
	if exact == 0:
		return Vector2i(0, 0)

	var fuzz_chance := 0.0
	var width       := 0

	match max_rarity:
		1:  # COMMON：40% 模糊，范围差固定为 1
			fuzz_chance = 0.4
			width = 1
		2:  # FINE：55% 模糊，范围差固定为 1
			fuzz_chance = 0.55
			width = 1
		3:  # RARE：70% 模糊，范围差 1 或 2 各半
			fuzz_chance = 0.7
			width = 1 if randf() < 0.5 else 2
		4:  # LEGENDARY：90% 模糊，范围差多为 2，极少为 3
			fuzz_chance = 0.9
			width = 3 if randf() < 0.1 else 2

	# 不触发模糊时返回精确值
	if randf() >= fuzz_chance:
		return Vector2i(exact, exact)

	# 非对称偏移：exact 随机落在范围内的任意位置
	var lower   = randi_range(0, width)
	var upper   = width - lower
	var range_min = max(0, exact - lower)
	var range_max = min(8, exact + upper)
	# 模糊范围触及 0 时整体上移 1（避免误判为空格，同时保留范围宽度）
	if range_min == 0 and range_max > 0:
		range_min = 1
		range_max = min(8, range_max + 1)
	return Vector2i(range_min, range_max)

# -------------------------------------------------------
# 信号处理
# -------------------------------------------------------

func _on_cell_requested_dig(cell):
	if not map_generated:
		generate_map_avoiding(cell)
	cell.do_dig()
	if cell.is_artifact:
		score += SCORE_DAMAGED[cell.artifact_rarity]
	if cell.is_damaged:
		reduce_neighbor_fuzz(cell)
	update_ui()
	check_game_over()

func _on_cell_requested_brush(cell):
	if not map_generated:
		generate_map_avoiding(cell)
	if brush_count <= 0:
		return
	brush_count -= 1
	cell.do_brush()
	if cell.is_artifact:
		score += SCORE_INTACT[cell.artifact_rarity]
	update_ui()
	check_game_over()

# -------------------------------------------------------
# 损坏文物 → 周围数字变精确
# -------------------------------------------------------

func reduce_neighbor_fuzz(damaged_cell):
	var pos = cell_pos[damaged_cell]
	var row = pos.x
	var col = pos.y
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var r = row + dr
			var c = col + dc
			if r >= 0 and r < ROWS and c >= 0 and c < COLS:
				var neighbor = cells[r][c]
				if neighbor.is_artifact:
					continue
				var exact         = count_adjacent_artifacts(r, c)
				var current_width = neighbor.number_max - neighbor.number_min
				# 已精确或范围差为1时直接变精确
				if current_width <= 1:
					neighbor.number_min = exact
					neighbor.number_max = exact
				else:
					# 范围差减1，exact 仍保持在范围内
					var new_width = current_width - 1
					var max_lower = min(new_width, exact)
					var lower     = randi_range(0, max_lower)
					var upper     = new_width - lower
					neighbor.number_min = exact - lower
					neighbor.number_max = exact + upper
					# 边界修正：下限至少为 1，上限至多为 8
					if neighbor.number_min < 1:
						neighbor.number_max += (1 - neighbor.number_min)
						neighbor.number_min = 1
					if neighbor.number_max > 8:
						neighbor.number_min -= (neighbor.number_max - 8)
						neighbor.number_max = 8
				if neighbor.is_revealed:
					neighbor.update_visuals()

# -------------------------------------------------------
# 游戏结束判断
# -------------------------------------------------------

func check_game_over():
	# 所有文物都翻开了就结束
	for row in ROWS:
		for col in COLS:
			var cell = cells[row][col]
			if cell.is_artifact and not cell.is_revealed:
				return
	end_game()

func end_game():
	# 自动翻开剩余非文物格子
	for row in ROWS:
		for col in COLS:
			var cell = cells[row][col]
			if not cell.is_revealed:
				cell.is_revealed = true
				cell.update_visuals()
	# 禁用所有格子，防止继续点击
	for row in ROWS:
		for col in COLS:
			cells[row][col].disabled = true
	score_label.text = "Final: " + str(score)

# -------------------------------------------------------
# UI
# -------------------------------------------------------

func update_ui():
	brush_label.text = "Brush: " + str(brush_count)
	score_label.text  = "Score: "  + str(score)
