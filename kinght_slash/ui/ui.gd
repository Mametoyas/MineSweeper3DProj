extends Control

func _ready():
	# เชื่อมปุ่มแต่ละอันเข้ากับฟังก์ชัน
	$StartButton.pressed.connect(_on_start_pressed)
	$OptionsButton.pressed.connect(_on_options_pressed)
	$TutorialButton.pressed.connect(_on_tutorial_pressed)
	$ExitButton.pressed.connect(_on_exit_pressed)


func _on_start_pressed():
	# โหลดฉากหลัก (เช่น Main.tscn)
	get_tree().change_scene_to_file("res://Scenes/demo_scene.tscn")

func _on_options_pressed():
	print("Open Options menu (ยังไม่ทำ)")

func _on_tutorial_pressed():
	print("Open Tutorial (ยังไม่ทำ)")
	# ตัวอย่าง: get_tree().change_scene_to_file("res://Scenes/tutorial.tscn")

func _on_exit_pressed():
	get_tree().quit()
