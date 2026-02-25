extends Control

# 展示顺序：common × 5 → fine × 3 → rare × 1 → legendary × 1
const ARTIFACT_ORDER = [
	"pottery", "adze", "awl", "shell", "coin",
	"jade", "painted_pot", "mirror",
	"mask",
	"tree",
]

const RARITY_EMOJI = { 1: "🏺", 2: "💎", 3: "⭐", 4: "👑" }

# 各稀有度的卡片背景色 / 描边色
const RARITY_BG = {
	1: Color(0.85, 0.78, 0.60),   # 暖米色
	2: Color(0.65, 0.80, 0.90),   # 天蓝
	3: Color(0.80, 0.65, 0.90),   # 薰衣草
	4: Color(0.95, 0.82, 0.30),   # 金色
}
const RARITY_BORDER = {
	1: Color(0.70, 0.60, 0.40),
	2: Color(0.40, 0.65, 0.85),
	3: Color(0.60, 0.40, 0.85),
	4: Color(0.85, 0.65, 0.10),
}

@onready var stats_label    = $CenterContainer/VBoxContainer/StatsLabel
@onready var grid_container = $CenterContainer/VBoxContainer/GridContainer
@onready var back_button    = $CenterContainer/VBoxContainer/BackButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_populate_cards()

func _populate_cards():
	var found_count = 0
	for id in ARTIFACT_ORDER:
		var col_data = GameData.museum_collection.get(id, {})
		if col_data.get("found", 0) > 0:
			found_count += 1
		grid_container.add_child(_make_card(id))
	stats_label.text = "已收集：" + str(found_count) + " / " + str(ARTIFACT_ORDER.size())

func _make_card(artifact_id: String) -> Control:
	var def      = GameData.ARTIFACT_DEFS[artifact_id]
	var col_data = GameData.museum_collection.get(artifact_id, {})
	var found    = col_data.get("found", 0)
	var intact   = col_data.get("intact", 0)
	var rarity   = def["rarity"]
	var locked   = found == 0

	# ── 外层 PanelContainer（固定尺寸 + 圆角背景）──
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 175)

	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left     = 8
	sb.corner_radius_top_right    = 8
	sb.corner_radius_bottom_left  = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.content_margin_left   = 12.0
	sb.content_margin_right  = 12.0
	sb.content_margin_top    = 14.0
	sb.content_margin_bottom = 14.0
	if locked:
		sb.bg_color     = Color(0.22, 0.22, 0.22)
		sb.border_color = Color(0.38, 0.38, 0.38)
	else:
		sb.bg_color     = RARITY_BG[rarity]
		sb.border_color = RARITY_BORDER[rarity]
	panel.add_theme_stylebox_override("panel", sb)

	# ── 内层 VBoxContainer ──
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Emoji / 问号
	var emoji_lbl = Label.new()
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 40)
	emoji_lbl.text = "❓" if locked else RARITY_EMOJI[rarity]
	vbox.add_child(emoji_lbl)

	# 文物名称
	var name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 16)
	if locked:
		name_lbl.text = "???"
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		name_lbl.text = def["name"]
	vbox.add_child(name_lbl)

	# 发现统计
	var stat_lbl = Label.new()
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", 14)
	if locked:
		stat_lbl.text = "未发现"
		stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		stat_lbl.text = "发现 " + str(found) + " 次\n完整 " + str(intact) + " 件"
	vbox.add_child(stat_lbl)

	return panel

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
