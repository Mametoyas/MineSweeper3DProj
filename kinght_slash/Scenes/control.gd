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

@onready var upgrade_panel = $UpgradePanel
@onready var btn1 = $UpgradePanel/VBoxContainer/Button1
@onready var btn2 = $UpgradePanel/VBoxContainer/Button2
@onready var btn3 = $UpgradePanel/VBoxContainer/Button3

@onready var skill_cd_label = $SkillCooldownLabel

@onready var combo_label = $ComboLabel

@onready var crit_text = $BattleText_Crit
@onready var berserk_text = $BattleText_Berserk

var current_options = []
var player_ref = null

# ---- ฟังก์ชันอัปเกรดแต่ละอัน ---- #
func _upgrade_max_hp(p):
	p.max_hp += 20
	p.hp = p.max_hp
	if p.ui:
		p.ui.set_hp(p.hp, p.max_hp)

func _upgrade_attack(p):
	p.attack_damage += 5

func _upgrade_attack_speed(p):
	p.attack_cooldown *= 0.8

func _upgrade_skill_power(p):
	p.skill_power *= 1.2

func _upgrade_move_speed(p):
	p.move_speed *= 1.1

func _upgrade_exp_gain(p):
	p.exp_gain_rate *= 1.2

# ---- ฟังก์ชันอัปเกรดเพิ่มเติม ---- #

# ฟื้นฟูเลือดทันที
func _upgrade_heal(p):
	var heal_amount = int(p.max_hp * 0.5)
	p.hp = clamp(p.hp + heal_amount, 0, p.max_hp)
	if p.ui:
		p.ui.set_hp(p.hp, p.max_hp)
	print("💚 Healed", heal_amount, "HP!")

# ฟื้นฟู HP อัตโนมัติเล็กน้อยต่อวินาที
func _upgrade_regen(p):
	if not p.has_meta("regen_active"):
		p.set_meta("regen_active", true)
		var regen_timer = Timer.new()
		regen_timer.wait_time = 1.0
		regen_timer.one_shot = false
		p.add_child(regen_timer)
		regen_timer.timeout.connect(func():
			if not p.is_dead:
				p.hp = clamp(p.hp + 2, 0, p.max_hp)
				if p.ui:
					p.ui.set_hp(p.hp, p.max_hp)
		)
		regen_timer.start()
		print("🌿 HP Regen Activated!")

# เพิ่มเวลาสกิลหมุน +2 วิ
func _upgrade_spin_duration(p):
	p.spin_bonus_duration = (p.spin_bonus_duration if p.has_meta("spin_bonus_duration") else 0) + 2
	print("🌀 Spin Skill lasts +2s longer!")

# เพิ่มความแรงของการตีศัตรู (knockback)
func _upgrade_knockback(p):
	p.knockback_strength = (p.knockback_strength if p.has_meta("knockback_strength") else 5.0) * 1.5
	print("💥 Knockback increased!")

# ลดคูลดาวน์สกิลทั้งหมด -20%
func _upgrade_cooldown_reduction(p):
	p.skill_cooldown *= 0.8
	print("⏳ Skill Cooldown reduced!")

# เพิ่ม EXP drop จากศัตรูอีก +50%
func _upgrade_bonus_drop(p):
	p.exp_gain_rate *= 1.5
	print("⭐ EXP gain rate boosted!")

# เพิ่มโอกาส Critical Hit 20%
func _upgrade_crit_chance(p):
	p.crit_chance = (p.crit_chance if p.has_meta("crit_chance") else 0.0) + 0.2
	print("🔥 Critical Chance +20%!")

# เพิ่ม Damage ตอนเลือดต่ำ (Berserk)
func _upgrade_berserk(p):
	p.berserk_active = true
	print("💢 Berserk Mode: +50% damage under 30% HP!")

# เพิ่ม Armor ลดความเสียหายที่ได้รับ -20%
func _upgrade_armor(p):
	p.damage_reduction = (p.damage_reduction if p.has_meta("damage_reduction") else 0.0) + 0.2
	print("🛡️ Damage taken reduced by 20%!")

# เพิ่มระยะการโจมตี
func _upgrade_attack_range(p):
	p.attack_range_bonus = (p.attack_range_bonus if p.has_meta("attack_range_bonus") else 0.0) + 0.5
	print("⚔️ Attack range increased!")
	
# โอกาสดูดเลือดเมื่อโจมตี (Life Steal)
func _upgrade_lifesteal(p):
	p.lifesteal = (p.lifesteal if p.has_meta("lifesteal") else 0.0) + 0.05
	print("🩸 Life Steal +5%! Heal when dealing damage.")

# เพิ่มดาเมจจากคอมโบ (Combo Power)
func _upgrade_combo_damage(p):
	p.combo_damage_boost = (p.combo_damage_boost if p.has_meta("combo_damage_boost") else 0.0) + 0.1
	print("⚡ Combo Damage +10%! Each hit gets stronger in a combo.")
		
# Double Slash — มีโอกาสตีซ้ำทันที
func _upgrade_double_slash(p):
	p.double_slash_chance = (p.double_slash_chance if p.has_meta("double_slash_chance") else 0.0) + 0.15
	print("⚔️ Double Slash +15%! Chance to hit twice per swing!")
	
# Critical Heal — ฟื้น HP เมื่อคริติคัล
func _upgrade_crit_heal(p):
	p.crit_heal = (p.crit_heal if p.has_meta("crit_heal") else 0.0) + 0.05
	print("💖 Heal 5% HP on critical hits!")

# ---- รวมเข้าในลิสต์ ---- #
var upgrades = [
	{"name": "Max HP +20", "effect": _upgrade_max_hp},
	{"name": "Attack +5", "effect": _upgrade_attack},
	{"name": "Attack Speed +20%", "effect": _upgrade_attack_speed},
	{"name": "Skill Power +20%", "effect": _upgrade_skill_power},
	{"name": "Move Speed +10%", "effect": _upgrade_move_speed},
	{"name": "Gain More EXP +20%", "effect": _upgrade_exp_gain},
	{"name": "Instant Heal 50% HP", "effect": _upgrade_heal},
	{"name": "Auto HP Regen", "effect": _upgrade_regen},
	{"name": "Spin Duration +2s", "effect": _upgrade_spin_duration},
	{"name": "Knockback Power +50%", "effect": _upgrade_knockback},
	{"name": "Cooldown Reduction -20%", "effect": _upgrade_cooldown_reduction},
	{"name": "EXP Drop +50%", "effect": _upgrade_bonus_drop},
	{"name": "Critical Chance +20%", "effect": _upgrade_crit_chance},
	{"name": "Berserk Mode", "effect": _upgrade_berserk},
	{"name": "Armor +20%", "effect": _upgrade_armor},
	{"name": "Attack Range +50%", "effect": _upgrade_attack_range},
	{"name": "Life Steal +5%", "effect": _upgrade_lifesteal},
	{"name": "Combo Damage +10%", "effect": _upgrade_combo_damage},
	{"name": "Double Slash +15%", "effect": _upgrade_double_slash},
]


# ---------- SETUP ---------- #
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	update_hp_bar()
	update_exp_bar(0.0)
	upgrade_panel.visible = false


# ---------- HP ---------- #
func set_hp(current: int, max_value: int):
	current_hp = clamp(current, 0, max_value)
	max_hp = max_value
	update_hp_bar()

func update_hp_bar():
	var percent = float(current_hp) / float(max_hp)
	hp_fill.size.x = hp_back.size.x * percent
	hp_label.text = str(current_hp) + " / " + str(max_hp)


# ---------- EXP ---------- #
func update_exp_bar(percent: float):
	var tween = get_tree().create_tween()
	tween.tween_property(exp_fill, "size:x", exp_back.size.x * percent, 0.4)
	exp_label.text = "EXP: " + str(int(percent * 100)) + "%"


# ---------- LEVEL ---------- #
func update_level(lv: int):
	level_label.text = "Lv. " + str(lv)


# ---------- FLASH DAMAGE ---------- #
func flash_screen_red():
	var tween = get_tree().create_tween()
	damage_flash.color = Color(1, 0, 0, 0.2)
	tween.tween_property(damage_flash, "color", Color(1, 0, 0, 0), 0.4)


# ---------- SKILL COOLDOWN ---------- #
func show_skill_cooldown(duration):
	skill_cd_label.text = "Skill CD: " + str(duration)
	var tween = get_tree().create_tween()
	tween.tween_method(func(t): skill_cd_label.text = "Skill CD: " + str(int(duration - t)), 0.0, duration, duration)
	await tween.finished
	skill_cd_label.text = "Skill Ready!"


# ---------- UPGRADE CHOICE ---------- #
func show_upgrade_choices(player):
	player_ref = player
	upgrade_panel.visible = true

	# ✅ สุ่ม 3 ตัวเลือก
	current_options = upgrades.duplicate()
	current_options.shuffle()
	current_options = current_options.slice(0, 3)

	btn1.text = current_options[0]["name"] + "\n[Press 1]"
	btn2.text = current_options[1]["name"] + "\n[Press 2]"
	btn3.text = current_options[2]["name"] + "\n[Press 3]"

	# ✅ ตัดการเชื่อม signal เก่าก่อนต่อใหม่
	for connection in btn1.pressed.get_connections():
		btn1.pressed.disconnect(connection.callable)
	for connection in btn2.pressed.get_connections():
		btn2.pressed.disconnect(connection.callable)
	for connection in btn3.pressed.get_connections():
		btn3.pressed.disconnect(connection.callable)

	btn1.pressed.connect(func(): _on_choice_pressed(0))
	btn2.pressed.connect(func(): _on_choice_pressed(1))
	btn3.pressed.connect(func(): _on_choice_pressed(2))
	

func _on_choice_pressed(index):
	if not player_ref:
		return

	var choice = current_options[index]
	# ✅ เรียกฟังก์ชันใน effect โดยตรง (ไม่ต้องส่งฟังก์ชันซ้ำ)
	choice["effect"].call(player_ref)	
	upgrade_panel.visible = false


# ---------- KEYBOARD CHOICES ---------- #
func _unhandled_input(event):
	if not upgrade_panel.visible:
		return

	if event.is_action_pressed("choose_1"):
		_on_choice_pressed(0)
	if event.is_action_pressed("choose_2"):
		_on_choice_pressed(1)
	if event.is_action_pressed("choose_3"):
		_on_choice_pressed(2)

func show_combo(count: int, tier: String):
	combo_label.visible = true
	combo_label.text = "COMBO " + str(count) + "  [" + tier + "]"
	combo_label.modulate = Color(1, 0.8, 0.2)  # สีทอง

	var tween = get_tree().create_tween()
	combo_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(combo_label, "scale", Vector2(1, 1), 0.2)

func hide_combo():
	combo_label.visible = false
	
# 🔥 ข้อความ Critical
func show_critical():
	crit_text.text = "CRITICAL!"
	crit_text.modulate = Color(1, 0.3, 0.3)
	crit_text.visible = true
	crit_text.scale = Vector2(1.5, 1.5)

	var tween = get_tree().create_tween()
	tween.tween_property(crit_text, "scale", Vector2(1, 1), 0.15)
	tween.tween_property(crit_text, "modulate:a", 0.0, 0.6)
	await tween.finished
	crit_text.visible = false
	crit_text.modulate.a = 1.0


# 💢 ข้อความ Berserk
func show_berserk():
	berserk_text.text = "BERSERK MODE!"
	berserk_text.modulate = Color(1, 0, 0)
	berserk_text.visible = true
	berserk_text.scale = Vector2(2, 2)

	var tween = get_tree().create_tween()
	tween.tween_property(berserk_text, "scale", Vector2(1, 1), 0.25)
	tween.tween_property(berserk_text, "modulate:a", 0.0, 1.2)
	await tween.finished
	berserk_text.visible = false
	berserk_text.modulate.a = 1.0
