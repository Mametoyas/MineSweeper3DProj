extends Control

var max_hp := 100
var current_hp := 100

@onready var hp_fill = $HP_Fill
@onready var hp_label = $HP_Label
@onready var hp_back = $HP_Back

func _ready():
	update_hp_bar()

func set_hp(value: int):
	current_hp = clamp(value, 0, max_hp)
	update_hp_bar()

func update_hp_bar():
	var percent = float(current_hp) / float(max_hp)
	hp_fill.size.x = hp_back.size.x * percent
	hp_label.text = str(int(percent * 100)) + "%"

func update_level(lv: int, current_exp: int, next_exp: int):
	$LevelLabel.text = "Lv. " + str(lv) + " (" + str(current_exp) + "/" + str(next_exp) + ")"
