extends CharacterBody3D

# ---------- PLAYER PROPERTIES ---------- #
@export var move_speed: float = 6
@export var skill_cooldown: float = 15.0
@export var follow_lerp_factor: float = 4.0

# ---------- GAMEPLAY VARIABLES ---------- #
var is_grounded = false
var can_attack = true
var is_attacking = false
var attack_cooldown = 0.1
var combo_step = 0
var attack_queued = false
var combo_buffer_time = 0.3
var max_hp = 100
var hp = 100
var hit_targets: Array = []
var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 100
var is_dead = false
var can_use_skill: bool = true
var attack_damage: float = 10.0
var skill_power: float = 1.0
var exp_gain_rate: float = 1.0

# ---------- UPGRADEABLE STATS ---------- #
var crit_chance: float = 0.0
var damage_reduction: float = 0.0
var knockback_strength: float = 5.0
var spin_bonus_duration: float = 0.0
var attack_range_bonus: float = 0.0
var berserk_active: bool = false

# ---------- SPECIAL STATS (New Abilities) ---------- #
var lifesteal: float = 0.0                   # 🩸 ฟื้นเลือดจากดาเมจ
var combo_damage_boost: float = 0.0          # ⚡ ดาเมจเพิ่มตามคอมโบ
var revive_ready: bool = false               # 💫 ฟื้นชีวิต 1 ครั้ง
var double_slash_chance: float = 0.0         # ⚔️ โอกาสตีซ้ำ
var crit_heal: float = 0.0                   # 💖 ฟื้นเลือดเมื่อคริติคอล

# ---------- NODE REFERENCES ---------- #
@onready var model = $Rig
@onready var animation = $Rig/AnimationPlayer
@onready var spring_arm = %Gimbal
@onready var sword_hitbox = $"Rig/Skeleton3D/2H_Sword/SwordHitbox"
@onready var particle_trail = $ParticleTrail
@onready var footsteps = $Footsteps
@onready var ui = get_tree().get_current_scene().get_node("userinterface/Control")

# ---------- COMBO SYSTEM ---------- #
var combo_count: int = 0
var combo_timer: Timer
var combo_tier: String = ""
@export var combo_timeout: float = 3.0

# ---------- CONSTANTS ---------- #
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

# ---------- DASH SYSTEM ---------- #
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0

var is_dashing: bool = false
var can_dash: bool = true



# ---------- READY ---------- #
func _ready():
	combo_timer = Timer.new()
	combo_timer.wait_time = combo_timeout
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)

func perform_dash():
	if not can_dash or is_attacking or is_dead:
		return
	if not is_on_floor():
		return

	is_dashing = true
	can_dash = false
	var dash_dir = Vector3(velocity.x, 0, velocity.z).normalized()

	# ถ้าไม่ได้เคลื่อนที่ ให้ dash ไปข้างหน้าตามทิศตัวละคร
	if dash_dir == Vector3.ZERO:
		dash_dir = -transform.basis.z

	## ✅ เล่นแอนิเมชัน dash ถ้ามี
	#if animation.has_animation("Dodge_Forward"):
	animation.play("Dodge_Forward")
	
	# ✅ ให้ player มี invincible ช่วงสั้น ๆ (iframe)
	set_meta("invincible", true)

	var dash_time := 0.0
	while dash_time < dash_duration:
		dash_time += get_process_delta_time()
		velocity = dash_dir * dash_speed
		move_and_slide()
		await get_tree().process_frame

	# ✅ รีเซ็ตหลัง dash จบ
	is_dashing = false
	set_meta("invincible", false)
	velocity = Vector3.ZERO

	# ✅ Cooldown
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

# ---------- PROCESS ---------- #
func _process(delta):
	if is_dead:
		return

	player_animations()
	get_input(delta)

	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)

	if is_moving():
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)

	is_grounded = is_on_floor()
	
	# Dash (Shift)
	if Input.is_action_just_pressed("dash"):
		perform_dash()

	if Input.is_action_just_pressed("attack"):
		if can_attack and not is_attacking:
			perform_attack()
		elif is_attacking:
			attack_queued = true

	if Input.is_action_just_pressed("skill") and can_use_skill:
		use_spin_skill()

	velocity.y -= gravity * delta


# ---------- ATTACK SYSTEM ---------- #
func perform_attack():
	can_attack = false
	is_attacking = true
	attack_queued = false
	hit_targets.clear()

	var attack_anim = ""
	match combo_step:
		0:
			attack_anim = "2H_Melee_Attack_Slice"
			combo_step = 1
		1:
			attack_anim = "2H_Melee_Attack_Chop"
			combo_step = 2
		2:
			attack_anim = "2H_Melee_Attack_Spin"
			combo_step = 0

	# ✅ ปรับความเร็วอนิเมชันตาม attack_cooldown
	var base_attack_speed = 0.1
	var speed_scale = base_attack_speed / attack_cooldown
	animation.speed_scale = clamp(speed_scale, 0.5, 3.0)

	sword_hitbox.monitoring = true
	animation.play(attack_anim)
	await animation.animation_finished
	animation.speed_scale = 1.0
	sword_hitbox.monitoring = false
	is_attacking = false

	if attack_queued:
		perform_attack()
	else:
		await get_tree().create_timer(combo_buffer_time).timeout
		can_attack = true


# ---------- ฟันโดนศัตรู ---------- #
func _on_sword_hitbox_body_entered(body):
	if body.is_in_group("Enemy") and body not in hit_targets:
		var dir = (body.global_position - global_position).normalized()
		var dmg = attack_damage

		# ⚡ Combo Damage Boost
		if combo_count > 0 and combo_damage_boost > 0.0:
			dmg *= (1.0 + combo_damage_boost * combo_count)

		# 💢 Berserk
		if berserk_active and hp < max_hp * 0.3:
			dmg *= 1.5
			if ui:
				ui.show_berserk()

		# 🔥 Critical
		var is_crit = randf() < crit_chance
		if is_crit:
			dmg *= 2.0
			if ui:
				ui.show_critical()
			print("🔥 Critical Hit!")
			if crit_heal > 0.0:
				var heal = int(dmg * crit_heal)
				hp = clamp(hp + heal, 0, max_hp)
				ui.set_hp(hp, max_hp)
				print("💖 Crit Heal +", heal)

		# 🩸 Life Steal
		if lifesteal > 0.0:
			var heal = int(dmg * lifesteal)
			hp = clamp(hp + heal, 0, max_hp)
			ui.set_hp(hp, max_hp)
			print("🩸 Life Steal +", heal)

		# ⚔️ Double Slash
		if randf() < double_slash_chance:
			print("⚔️ Double Slash!")
			body.take_damage(dmg, dir)

		body.take_damage(dmg, dir)
		add_combo()
		hit_targets.append(body)


# ---------- SPIN SKILL ---------- #
func use_spin_skill():
	can_use_skill = false
	is_attacking = true
	animation.play("2H_Melee_Attack_Spinning")
	sword_hitbox.monitoring = true

	var spin_duration = 4.0 + spin_bonus_duration
	var tick_interval = 0.3
	var timer = 0.0
	var elapsed = 0.0

	while elapsed < spin_duration and not is_dead:
		elapsed += get_process_delta_time()
		timer += get_process_delta_time()

		if timer >= tick_interval:
			timer = 0.0
			for body in sword_hitbox.get_overlapping_bodies():
				if body.is_in_group("Enemy"):
					body.take_damage(30 * skill_power, (body.global_position - global_position).normalized())
					add_combo()
					print("Spin Tick!")

		await get_tree().process_frame

	sword_hitbox.monitoring = false
	is_attacking = false

	if ui:
		ui.show_skill_cooldown(skill_cooldown)

	await get_tree().create_timer(skill_cooldown).timeout
	can_use_skill = true


# ---------- DAMAGE / DEATH SYSTEM ---------- #
func take_damage(amount):
	if is_dead:
		return

	amount *= (1.0 - damage_reduction)
	hp = clamp(hp - amount, 0, max_hp)

	ui.set_hp(hp, max_hp)
	ui.flash_screen_red()
	play_hit_animation()

	if hp <= 0:
		is_dead = true
		play_death_animation()


func play_hit_animation():
	if not is_attacking and not is_dead:
		animation.play("Hit_A")
		can_attack = false
		await animation.animation_finished
		can_attack = true


func play_death_animation():
	can_attack = false
	is_attacking = false
	velocity = Vector3.ZERO
	animation.play("Death_B")
	await animation.animation_finished
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://ui/game_over.tscn")


# ---------- COMBO SYSTEM ---------- #
func add_combo():
	combo_count += 1
	combo_timer.start()
	update_combo_tier()
	if ui and ui.has_method("show_combo"):
		ui.show_combo(combo_count, combo_tier)

func _on_combo_timeout():
	combo_count = 0
	combo_tier = ""
	if ui and ui.has_method("hide_combo"):
		ui.hide_combo()

func update_combo_tier():
	match combo_count:
		1, 2, 3:
			combo_tier = "F"
		4, 5:
			combo_tier = "E"
		6, 7:
			combo_tier = "D"
		8, 9:
			combo_tier = "C"
		10, 11:
			combo_tier = "B"
		12, 13:
			combo_tier = "A"
		14, 15:
			combo_tier = "S"
		16, 17, 18:
			combo_tier = "SS"
		_:
			if combo_count >= 19:
				combo_tier = "SSS"


# ---------- EXP / LEVEL SYSTEM ---------- #
func gain_exp(amount: int):
	current_exp += int(amount * exp_gain_rate)
	if current_exp >= exp_to_next:
		level_up()

	if ui:
		var percent = float(current_exp) / float(exp_to_next)
		ui.update_exp_bar(percent)

func level_up():
	current_exp -= exp_to_next
	level += 1
	exp_to_next = int(exp_to_next * 1.5)

	if ui:
		ui.update_exp_bar(0.0)
		ui.update_level(level)
		ui.show_upgrade_choices(self)
		ui.set_hp(hp, max_hp)


# ---------- MOVEMENT ---------- #
func get_input(_delta):
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_axis("move_left", "move_right")
	move_direction.z = Input.get_axis("move_forward", "move_back")
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = Vector3(move_direction.x * move_speed, velocity.y, move_direction.z * move_speed)
	move_and_slide()

func is_moving():
	return abs(velocity.z) > 0.1 or abs(velocity.x) > 0.1

func player_animations():
	if is_attacking:
		return
	particle_trail.emitting = false
	footsteps.stream_paused = true

	if is_on_floor():
		if is_moving():
			animation.play("Running_A", 0.5)
			particle_trail.emitting = true
			footsteps.stream_paused = false
		else:
			animation.play("2H_Melee_Idle", 0.5)
