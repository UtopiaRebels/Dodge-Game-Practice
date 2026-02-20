extends Button

# 格子状态
var is_mine: bool = false
var is_revealed: bool = false
var is_flagged: bool = false
var adjacent_mines: int = 0

# 颜色常量（占位用）
const COLOR_HIDDEN   = Color(0.4, 0.4, 0.4)  # 灰色：未翻开
const COLOR_REVEALED = Color(0.2, 0.8, 0.6)  # 白色：已翻开
const COLOR_MINE     = Color(1.0, 0.2, 0.2)  # 红色：地雷
const COLOR_FLAG     = Color(1.0, 0.8, 0.2)  # 黄色：旗子

@onready var label = $Label

func _ready():
	pressed.connect(_on_left_click)
	add_theme_color_override("font_color", Color.BLACK)
	update_visuals()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_revealed:
				return
			is_flagged = !is_flagged
			update_visuals()

func _on_left_click():
	if is_flagged or is_revealed:
		return
	is_revealed = true
	update_visuals()

func update_visuals():
	if is_flagged:
		label.text = "🚩"
		add_theme_stylebox_override("normal", make_stylebox(COLOR_FLAG))
	elif not is_revealed:
		label.text = ""
		add_theme_stylebox_override("normal", make_stylebox(COLOR_HIDDEN))
	elif is_mine:
		label.text = "💣"
		add_theme_stylebox_override("normal", make_stylebox(COLOR_MINE))
	else:
		label.text = str(adjacent_mines) if adjacent_mines > 0 else ""
		add_theme_stylebox_override("normal", make_stylebox(COLOR_REVEALED))

# 创建纯色背景的辅助函数
func make_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.4, 0.4, 0.4)
	return sb
