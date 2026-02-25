extends Control

@onready var back_button = $CenterContainer/VBoxContainer/BackButton

func _ready():
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
