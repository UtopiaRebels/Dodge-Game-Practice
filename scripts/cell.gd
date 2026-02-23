extends Button

# 文物稀有度
enum ArtifactRarity { NONE = 0, COMMON = 1, FINE = 2, RARE = 3, LEGENDARY = 4 }

# 格子状态
var is_artifact: bool = false
var artifact_rarity: ArtifactRarity = ArtifactRarity.NONE
var is_revealed: bool = false
var is_damaged: bool = false

# 模糊数字：精确时 min == max，模糊时 min < max
var number_min: int = 0
var number_max: int = 0

# 信号：交由父节点（Grid）处理资源逻辑
signal requested_dig(cell)
signal requested_brush(cell)

# 颜色常量
const COLOR_HIDDEN   = Color(0.4, 0.4, 0.4)     # 灰：未挖开
const COLOR_REVEALED = Color(0.85, 0.75, 0.55)   # 沙色：已挖开（空地/数字）
const COLOR_ARTIFACT = Color(0.2, 0.7, 0.4)      # 绿：完整文物
const COLOR_DAMAGED  = Color(0.7, 0.3, 0.2)      # 红褐：损坏文物

# 稀有度对应的 emoji
const RARITY_EMOJI = {
	ArtifactRarity.COMMON:    "🏺",
	ArtifactRarity.FINE:      "💎",
	ArtifactRarity.RARE:      "⭐",
	ArtifactRarity.LEGENDARY: "👑",
}

@onready var label = $Label

func _ready():
	pressed.connect(_on_left_click)
	add_theme_color_override("font_color", Color.BLACK)
	update_visuals()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if is_revealed:
				return
			# 右键：请求 Brush，由 Grid 检查资源后决定是否执行
			requested_brush.emit(self)

func _on_left_click():
	if is_revealed:
		return
	# 左键：请求普通挖掘
	requested_dig.emit(self)

# 由 Grid 调用：执行普通挖掘（损坏文物）
func do_dig():
	if is_revealed:
		return
	is_revealed = true
	if is_artifact:
		is_damaged = true
	update_visuals()

# 由 Grid 调用：执行 Brush（保护文物）
func do_brush():
	if is_revealed:
		return
	is_revealed = true
	# is_damaged 保持 false，文物完整
	update_visuals()

# 返回显示用的数字字符串
func get_number_text() -> String:
	if number_min == 0 and number_max == 0:
		return ""
	if number_min == number_max:
		return str(number_min)
	return str(number_min) + "~" + str(number_max)

func update_visuals():
	if not is_revealed:
		label.text = ""
		add_theme_stylebox_override("normal", make_stylebox(COLOR_HIDDEN))
	elif is_artifact:
		label.text = RARITY_EMOJI[artifact_rarity]
		var color = COLOR_ARTIFACT if not is_damaged else COLOR_DAMAGED
		add_theme_stylebox_override("normal", make_stylebox(color))
	else:
		label.text = get_number_text()
		add_theme_stylebox_override("normal", make_stylebox(COLOR_REVEALED))

func make_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.3, 0.3)
	return sb
