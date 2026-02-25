extends Control

@onready var play_button   = $CenterContainer/VBoxContainer/PlayButton
@onready var museum_button = $CenterContainer/VBoxContainer/MuseumButton
@onready var shop_button   = $CenterContainer/VBoxContainer/ShopButton
@onready var quit_button   = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	museum_button.pressed.connect(_on_museum_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/grid.tscn")

func _on_museum_pressed():
	get_tree().change_scene_to_file("res://scenes/museum.tscn")

func _on_shop_pressed():
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_quit_pressed():
	get_tree().quit()
