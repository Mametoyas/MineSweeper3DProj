extends Control

var max_hp := 100
var current_hp := 100

@onready var hp_fill = $HP_Fill
@onready var hp_label = $HP_Label
@onready var hp_back = $HP_Back

@onready var exp_fill = $EXP_Fill
@onready var exp_back = $EXP_Back
@onready var exp_label = $EXP_Label

@onready var level_label = $Level_Label

@onready var damage_flash = $DamageFlash

func _ready():
	update_hp_bar()
	update_exp_bar(0.0)

func set_hp(current: int, max_value: int):
	current_hp = clamp(current, 0, max_value)
	max_hp = max_value
	update_hp_bar()

func update_hp_bar():
	var percent = float(current_hp) / float(max_hp)
	hp_fill.size.x = hp_back.size.x * percent
	hp_label.text = str(current_hp) + " / " + str(max_hp)

func update_exp_bar(percent: float):
	# ใช้ Tween เพื่อให้ขยับนุ่ม ๆ
	var tween = get_tree().create_tween()
	tween.tween_property(exp_fill, "size:x", exp_back.size.x * percent, 0.4)
	exp_label.text = "EXP: " + str(int(percent * 100)) + "%"
	
# ----- LEVEL -----
func update_level(lv: int):
	level_label.text = "Lv. " + str(lv)
	
func flash_screen_red():
	# ยกเลิก tween เดิม (ถ้ามี)
	for child in get_tree().get_root().get_children():
		pass
	
	var tween = get_tree().create_tween()
	damage_flash.color = Color(1, 0, 0, 0.5)  # แดงชั่วคราว
	tween.tween_property(damage_flash, "color", Color(1, 0, 0, 0), 0.4)
	
func show_skill_cooldown(duration):
	$SkillCooldownLabel.text = "Skill CD: " + str(duration)
	var tween = get_tree().create_tween()
	tween.tween_method(func(t): $SkillCooldownLabel.text = "Skill CD: " + str(int(duration - t)), 0.0, duration, duration)
	await tween.finished
	$SkillCooldownLabel.text = "Skill Ready!"
