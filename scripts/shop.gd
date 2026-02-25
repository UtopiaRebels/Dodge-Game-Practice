extends Control

@onready var back_button    = $CenterContainer/VBoxContainer/BackButton
@onready var currency_label = $CenterContainer/VBoxContainer/CurrencyLabel
@onready var owned_label    = $CenterContainer/VBoxContainer/SpareBrushCard/ItemRow/OwnedLabel
@onready var buy_button     = $CenterContainer/VBoxContainer/SpareBrushCard/ItemRow/BuyButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	buy_button.pressed.connect(_on_buy_spare_brush)
	refresh_ui()

func refresh_ui():
	currency_label.text = "持有货币：" + str(GameData.currency)
	owned_label.text    = "持有：" + str(GameData.get_item_count("spare_brush"))
	# 货币不足时禁用购买按钮
	var price = GameData.ITEM_DEFS["spare_brush"]["price"]
	buy_button.disabled = GameData.currency < price

func _on_buy_spare_brush():
	if GameData.buy_item("spare_brush"):
		refresh_ui()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
