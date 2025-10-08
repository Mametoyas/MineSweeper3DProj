extends Control

func _ready():
	$RETRY.pressed.connect(_on_retry_pressed)
	$EXIT.pressed.connect(_on_exit_pressed)

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://Scenes/demo_scene.tscn")

func _on_exit_pressed():
	get_tree().change_scene_to_file("res://ui/ui.tscn")
