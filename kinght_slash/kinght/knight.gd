extends CharacterBody3D

# ---------- PLAYER PROPERTIES ---------- #
@export var move_speed: float = 6
@export var jump_force: float = 5
@export var follow_lerp_factor: float = 4
@export var jump_limit: int = 2
@export var skill_cooldown: float = 15.0

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
var hit_targets = []
var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 100
var is_dead = false
var can_use_skill: bool = true
var attack_damage = 10
var skill_power = 1.0
var exp_gain_rate = 1.0

# ---------- UPGRADEABLE STATS ---------- #
var crit_chance: float = 0.0
var damage_reduction: float = 0.0
var knockback_strength: float = 5.0
var spin_bonus_duration: float = 0.0
var attack_range_bonus: float = 0.0
var berserk_active: bool = false

# ---------- NODE REFERENCES ---------- #
@onready var model = $Rig
@onready var animation = $Rig/AnimationPlayer
@onready var spring_arm = %Gimbal
@onready var attack_area = $Rig/AttackArea
@onready var attack_area_final = $Rig/attack_area_final
@onready var particle_trail = $ParticleTrail
@onready var footsteps = $Footsteps
@onready var ui = get_tree().get_current_scene().get_node("userinterface/Control")

# ---------- CONSTANTS ---------- #
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2


# ---------- MAIN PROCESS ---------- #
func _process(delta):
	if is_dead:
		return

	player_animations()
	get_input(delta)

	# กล้องตามตัว
	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)

	# หมุนตัวตามทิศทางการเคลื่อนที่
	if is_moving():
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)

	is_grounded = is_on_floor()

	# โจมตีปกติ
	if Input.is_action_just_pressed("attack"):
		if can_attack and not is_attacking:
			perform_attack()
		elif is_attacking:
			attack_queued = true

	# ใช้สกิลหมุน
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
	var use_final_hitbox = false

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
			use_final_hitbox = true

	if use_final_hitbox:
		attack_area_final.monitoring = true
	else:
		attack_area.monitoring = true

	animation.play(attack_anim)
	await animation.animation_finished

	attack_area.monitoring = false
	attack_area_final.monitoring = false
	is_attacking = false

	if attack_queued:
		perform_attack()
	else:
		await get_tree().create_timer(combo_buffer_time).timeout
		can_attack = true


func _on_attack_area_body_entered(body):
	if body.is_in_group("Enemy") and body not in hit_targets:
		var dir = (body.global_position - global_position).normalized()

		var dmg = attack_damage
		if berserk_active and hp < max_hp * 0.3:
			dmg *= 1.5
			print("🔥 berserk_active")
		if randf() < crit_chance:
			dmg *= 2.0
			print("🔥 Critical Hit!")

		body.take_damage(dmg, dir)
		hit_targets.append(body)


func _on_attack_area_final_body_entered(body):
	if body.is_in_group("Enemy") and body not in hit_targets:
		var dir = (body.global_position - global_position).normalized()

		var dmg = attack_damage * 2.5
		if berserk_active and hp < max_hp * 0.3:
			dmg *= 1.5
			print("🔥 berserk_active")
		if randf() < crit_chance:
			dmg *= 2.0
			print("🔥 Critical Hit (Final Slash)!")

		body.take_damage(dmg, dir)
		hit_targets.append(body)


# ---------- SPIN SKILL ---------- #
func use_spin_skill():
	can_use_skill = false
	is_attacking = true
	animation.play("2H_Melee_Attack_Spinning")
	attack_area_final.monitoring = true

	var spin_duration = 4.0 + spin_bonus_duration
	var tick_interval = 0.5
	var timer = 0.0
	var elapsed = 0.0

	while elapsed < spin_duration and not is_dead:
		elapsed += get_process_delta_time()
		timer += get_process_delta_time()

		if timer >= tick_interval:
			timer = 0.0
			for body in attack_area_final.get_overlapping_bodies():
				if body.is_in_group("Enemy"):
					body.take_damage(30 * skill_power, (body.global_position - global_position).normalized())
					print("Spin Tick!")

		await get_tree().process_frame

	attack_area_final.monitoring = false
	is_attacking = false

	if ui:
		ui.show_skill_cooldown(skill_cooldown)

	await get_tree().create_timer(skill_cooldown).timeout
	can_use_skill = true


# ---------- MOVEMENT SYSTEM ---------- #
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


# ---------- DAMAGE / DEATH SYSTEM ---------- #
func take_damage(amount):
	if is_dead:
		return

	amount *= (1.0 - damage_reduction)
	hp -= amount
	hp = max(hp, 0)

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
