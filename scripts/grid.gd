extends Control

# 地图参数
const COLS = 10
const ROWS = 7
const ARTIFACT_COUNT = 10
const BRUSH_INITIAL = 5

# 各稀有度的分数（完整 / 损坏）
const SCORE_INTACT  = { 1: 10, 2: 35, 3: 130, 4: 280 }
const SCORE_DAMAGED = { 1:  5, 2: 10, 3:  45, 4:  70 }

const CellScene = preload("res://scenes/cell.tscn")

var cells: Array = []         # cells[row][col] -> Cell
var cell_pos: Dictionary = {} # Cell -> Vector2i(row, col)
var brush_count: int = BRUSH_INITIAL
var score: int = 0
var map_generated: bool = false

# 本局道具使用次数追踪
var spare_brush_used: int = 0

@onready var grid_container      = $CenterContainer/VBoxContainer/GridContainer
@onready var brush_label         = $CenterContainer/VBoxContainer/UI/BrushLabel
@onready var score_label         = $CenterContainer/VBoxContainer/UI/ScoreLabel
@onready var result_panel        = $CenterContainer/VBoxContainer/ResultPanel
@onready var rating_label        = $CenterContainer/VBoxContainer/ResultPanel/RatingLabel
@onready var stats_label         = $CenterContainer/VBoxContainer/ResultPanel/StatsLabel
@onready var restart_button      = $CenterContainer/VBoxContainer/ResultPanel/ButtonRow/RestartButton
@onready var main_menu_button    = $CenterContainer/VBoxContainer/ResultPanel/ButtonRow/MainMenuButton
@onready var spare_brush_label   = $CenterContainer/VBoxContainer/ItemBar/SpareBrushLabel
@onready var spare_brush_button  = $CenterContainer/VBoxContainer/ItemBar/SpareBrushUseButton

func _ready():
	generate_grid()
	update_ui()
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	spare_brush_button.pressed.connect(_on_use_spare_brush)

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
	# 按稀有度分拣 ARTIFACT_DEFS 中的 ID 并随机化
	var common_ids: Array = []
	var fine_ids:   Array = []
	var rare_ids:   Array = []
	var legend_ids: Array = []
	for id in GameData.ARTIFACT_DEFS:
		match GameData.ARTIFACT_DEFS[id]["rarity"]:
			1: common_ids.append(id)
			2: fine_ids.append(id)
			3: rare_ids.append(id)
			4: legend_ids.append(id)
	common_ids.shuffle()
	fine_ids.shuffle()
	rare_ids.shuffle()
	legend_ids.shuffle()

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

	# 剩余位置供 common / fine 使用
	var remaining: Array = []
	for p in range(COLS * ROWS):
		if p != rare_idx and p != legendary_idx and p != excluded_idx:
			remaining.append(p)
	remaining.shuffle()

	# 放置 rare 和 legendary
	_place_cell_artifact(rare_idx,      3, rare_ids[0])
	_place_cell_artifact(legendary_idx, 4, legend_ids[0])

	# 放置 5 个 common 和 3 个 fine
	for i in 5:
		_place_cell_artifact(remaining[i],     1, common_ids[i])
	for i in 3:
		_place_cell_artifact(remaining[5 + i], 2, fine_ids[i])

func _place_cell_artifact(idx: int, rarity: int, artifact_id: String):
	var cell = cells[idx / COLS][idx % COLS]
	cell.is_artifact     = true
	cell.artifact_rarity = rarity
	cell.artifact_id     = artifact_id

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
		1:  # COMMON：30% 模糊，范围差固定为 1
			fuzz_chance = 0.3
			width = 1
		2:  # FINE：50% 模糊，范围差固定为 1
			fuzz_chance = 0.5
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
	# 挖到空白格时立即扩散（含数字格边界，像传统扫雷）
	if not cell.is_artifact:
		var pos = cell_pos[cell]
		flood_fill_blank(pos.x, pos.y)
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
# 空白格自动扩散（BFS flood fill）
# -------------------------------------------------------

func flood_fill_blank(start_row: int, start_col: int):
	var start_cell = cells[start_row][start_col]
	# 只有空白格（min=max=0，非文物）才触发扩散
	if start_cell.is_artifact or start_cell.number_min != 0 or start_cell.number_max != 0:
		return

	var visited := {}
	var queue: Array[Vector2i] = [Vector2i(start_row, start_col)]
	visited[start_row * COLS + start_col] = true

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var cell = cells[pos.x][pos.y]

		# 自动揭开此空白格（若尚未揭开）
		if not cell.is_revealed:
			cell.is_revealed = true
			cell.update_visuals()

		# 向 8 方向扩展，只把空白格加入队列
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0:
					continue
				var r = pos.x + dr
				var c = pos.y + dc
				if r < 0 or r >= ROWS or c < 0 or c >= COLS:
					continue
				var key = r * COLS + c
				if visited.has(key):
					continue
				visited[key] = true
				var neighbor = cells[r][c]
				if neighbor.is_artifact or neighbor.is_revealed:
					continue
				if neighbor.number_min == 0 and neighbor.number_max == 0:
					# 空白格：加入队列继续扩散
					queue.append(Vector2i(r, c))
				else:
					# 数字格：直接揭开但不继续扩散
					neighbor.is_revealed = true
					neighbor.update_visuals()

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
	# 自动翻开剩余格子
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

	# 统计完整 / 损坏数量，同时收集博物馆数据
	var intact_count  = 0
	var damaged_count = 0
	var artifact_list: Array = []
	for row in ROWS:
		for col in COLS:
			var cell = cells[row][col]
			if cell.is_artifact:
				if cell.is_damaged:
					damaged_count += 1
				else:
					intact_count += 1
				artifact_list.append({
					"id":      cell.artifact_id,
					"rarity":  cell.artifact_rarity,
					"damaged": cell.is_damaged,
				})

	# 写入存档：货币 + 博物馆收藏
	GameData.add_currency(score)
	GameData.record_artifacts(artifact_list)

	# 更新顶部分数栏
	var rating = get_rating(score)
	score_label.text = "Score: " + str(score)

	# 显示评级（大字+配色）
	rating_label.text = rating
	var rating_color = {
		"S": Color(1.0, 0.84, 0.0),   # 金色
		"A": Color(0.27, 0.53, 1.0),  # 蓝色
		"B": Color(0.27, 0.73, 0.27), # 绿色
		"C": Color(1.0, 0.55, 0.27),  # 橙色
		"D": Color(0.55, 0.55, 0.55), # 灰色
	}
	rating_label.add_theme_color_override("font_color", rating_color[rating])

	# 显示统计摘要
	stats_label.text = (
		"完整 " + str(intact_count) + " 件　·　"
		+ "损坏 " + str(damaged_count) + " 件　·　"
		+ "剩余刷子 " + str(brush_count)
	)

	result_panel.visible = true

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_rating(s: int) -> String:
	# 满分约565（5C+3F+1R+1L全完整），全损坏约170
	# S≥440：传奇+稀有都完整（约125分区间，上限565）
	# A≥325：传奇损坏但其余全完整≈355（约114分区间）
	# B≥240：仅稀有完整≈255，加一两件其他≈260-280（约84分区间）
	# C≥175：少数低价值文物完整（约64分区间）
	# D＜175：几乎全部损坏（全损坏≈170→D）
	if s >= 440:
		return "S"
	elif s >= 325:
		return "A"
	elif s >= 240:
		return "B"
	elif s >= 175:
		return "C"
	else:
		return "D"

# -------------------------------------------------------
# UI
# -------------------------------------------------------

func update_ui():
	brush_label.text = "Brush: " + str(brush_count)
	score_label.text = "Score: " + str(score)
	update_item_bar()

func update_item_bar():
	var owned   = GameData.get_item_count("spare_brush")
	var limit   = GameData.ITEM_DEFS["spare_brush"]["run_limit"]
	var can_use = owned > 0 and spare_brush_used < limit
	spare_brush_label.text    = "备用软刷 ×" + str(owned)
	spare_brush_button.disabled = not can_use

func _on_use_spare_brush():
	var limit = GameData.ITEM_DEFS["spare_brush"]["run_limit"]
	if spare_brush_used >= limit:
		return
	if not GameData.consume_item("spare_brush"):
		return
	spare_brush_used += 1
	brush_count      += 1
	update_ui()
