extends CharacterBody3D

# ---------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 6
@export var jump_force : float = 5
@export var follow_lerp_factor : float = 4
@export var jump_limit : int = 2

@export_group("Game Juice")
@export var jumpStretchSize := Vector3(0.8, 1.2, 0.8)

# Booleans
var is_grounded = false
var can_attack = true
var is_attacking = false
var attack_cooldown = 0.1
var attack_index = 0 
var combo_step = 0
var attack_queued = false
var combo_buffer_time = 0.3
var max_hp = 100
var hp = 100
var hit_targets = []
var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 100 

@onready var attack_area_ab = $Rig/AttackArea
@onready var attack_area_final = $Rig/attack_area_final
# Onready Variables
@onready var model = $Rig
@onready var animation = $Rig/AnimationPlayer
@onready var spring_arm = %Gimbal

@onready var particle_trail = $ParticleTrail
@onready var footsteps = $Footsteps
@onready var attack_area = $Rig/AttackArea

@onready var ui = get_tree().get_current_scene().get_node("userinterface/Control")
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2


# ---------- FUNCTIONS ---------- #

func _process(delta):
	player_animations()
	get_input(delta)
	
	# Smoothly follow player's position
	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)
	
	# Player Rotation
	if is_moving():
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)
	
	# Check if player is grounded or not
	is_grounded = true if is_on_floor() else false
	
	# ✅ Attack
	if Input.is_action_just_pressed("attack"):
		if can_attack and not is_attacking:
			perform_attack()
		elif is_attacking:
			attack_queued = true
	
	velocity.y -= gravity * delta
	
func perform_attack():
	can_attack = false
	is_attacking = true
	attack_queued = false

	var attack_anim = ""
	var use_final_hitbox = false

	match combo_step:
		0:
			attack_anim = "2H_Melee_Attack_Slice"   # ท่าที่ 1
			combo_step = 1
		1:
			attack_anim = "2H_Melee_Attack_Chop"    # ท่าที่ 2
			combo_step = 2
		2:
			attack_anim = "2H_Melee_Attack_Spin" # ท่าสุดท้าย
			combo_step = 3
			use_final_hitbox = true

	hit_targets.clear()
	if use_final_hitbox:
		attack_area_final.monitoring = true
	else:
		attack_area_ab.monitoring = true

	# ✅ เปิด hitbox ให้ตรงท่า
	if use_final_hitbox:
		attack_area_final.monitoring = true
	else:
		attack_area_ab.monitoring = true

	animation.play(attack_anim)
	await animation.animation_finished

	# ✅ ปิด hitbox หลังตีจบ
	attack_area_ab.monitoring = false
	attack_area_final.monitoring = false
	is_attacking = false

	if attack_queued and combo_step < 3:
		perform_attack()  # ✅ ถ้ากดต่อระหว่างตี → ต่อคอมโบ
	else:
		await get_tree().create_timer(combo_buffer_time).timeout
		combo_step = 0
		can_attack = true
	
func _on_attack_area_body_entered(body):
	if body.is_in_group("Enemy") and body not in hit_targets:
		body.take_damage(10)
		hit_targets.append(body)  # ✅ ป้องกันดาเมจซ้ำในฟันเดียวกัน

func _on_attack_area_final_body_entered(body):
	if body.is_in_group("Enemy") and body not in hit_targets:
		body.take_damage(25)
		hit_targets.append(body)

func is_moving():
	return abs(velocity.z) > 0 || abs(velocity.x) > 0


# Get Player Input
func get_input(_delta):
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_axis("move_left", "move_right")
	move_direction.z = Input.get_axis("move_forward", "move_back")
	
	# Move The player Towards Spring Arm/Camera Rotation
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = Vector3(move_direction.x * move_speed, velocity.y, move_direction.z * move_speed)

	move_and_slide()

# Handle Player Animations
func player_animations():
	if is_attacking:
		return
	particle_trail.emitting = false
	footsteps.stream_paused = true
	
	if is_on_floor():
		if is_moving(): # Checks if player is moving
			animation.play("Running_A", 0.5)
			particle_trail.emitting = true
			footsteps.stream_paused = false
		else:
			animation.play("2H_Melee_Idle", 0.5)
			
func take_damage(amount):
	hp -= amount
	ui.set_hp(hp)
	print("Player HP:", hp)
	if hp <= 0:
		print("Player is dead!")
		
func gain_exp(amount: int):
	current_exp += amount
	print("Gained", amount, "EXP (", current_exp, "/", exp_to_next, ")")
	if current_exp >= exp_to_next:
		level_up()
		
func level_up():
	current_exp -= exp_to_next
	level += 1

	# เพิ่มสเตตตอนเลเวลอัป
	max_hp += 20
	hp = max_hp
	print("LEVEL UP! →", level, "HP:", hp)

	# เพิ่มความยากของการอัปเลเวลต่อไป
	exp_to_next = int(exp_to_next * 1.5)

	# อัปเดต UI ถ้ามี
	if ui.has_method("update_level"):
		ui.update_level(level, current_exp, exp_to_next)
