extends CharacterBody3D

# ---------- CONFIG ---------- #
@export var boss_name: String = "Bone Lord"
@export var move_speed: float = 4.0
@export var max_health: int = 2000
@export var attack_damage: int = 30
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 2.0
@export var phase2_threshold: float = 0.5       # HP เหลือ 50% เข้าสู่ Phase 2
@export var slam_damage: int = 80
@export var slam_radius: float = 8.0
@export var slam_interval: float = 6.0

# ---------- REFERENCES ---------- #
@onready var anim: AnimationPlayer = $Rig/AnimationPlayer
@onready var slam_area: Area3D = $SlamArea
@onready var player = get_tree().get_first_node_in_group("Player")
@onready var boss_ui = get_tree().get_current_scene().get_node("userinterface/Control")

# ---------- STATE ---------- #
var health: int
var can_attack: bool = true
var is_dead: bool = false
var in_phase2: bool = false
var slam_timer: float = 0.0
var spawner: Node = null

# ---------- KNOCKBACK ---------- #
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_strength: float = 5.0
var knockback_friction: float = 8.0

# ---------- SETUP ---------- #
func _ready():
	reset_state()


func reset_state():
	is_dead = false
	can_attack = true
	in_phase2 = false
	slam_timer = 0.0
	health = max_health
	velocity = Vector3.ZERO
	visible = true
	set_physics_process(true)
	anim.play("Idle_Combat")

	if boss_ui and boss_ui.has_method("show_boss_bar"):
		boss_ui.show_boss_bar(boss_name, health, max_health)

	print("👑 BOSS APPEARED:", boss_name)


# ------------------------------------------------------
# ⚙️ ฟิสิกส์หลักของบอส
# ------------------------------------------------------
func _physics_process(delta):
	if is_dead or not player:
		return

	# ✅ แรงโน้มถ่วง
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var dir = player.global_position - global_position
	dir.y = 0
	var distance = dir.length()

	# ✅ ถ้ามีแรงเด้งจากการโดนตี
	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
		return

	# ✅ ตรวจ Phase 2
	if not in_phase2 and health <= max_health * phase2_threshold:
		enter_phase2()

	# ✅ นับเวลา Slam
	if in_phase2:
		slam_timer += delta
		if slam_timer >= slam_interval:
			slam_attack()
			slam_timer = 0.0

	# ✅ ระยะโจมตี / เดิน
	if distance <= attack_range:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if can_attack:
			attack()
	else:
		anim.play("Walking_D_Skeletons")
		dir = dir.normalized()
		var target_rot = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 5)
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		move_and_slide()


# ------------------------------------------------------
# ⚔️ โจมตีปกติ
# ------------------------------------------------------
func attack():
	can_attack = false
	anim.play("1H_Melee_Attack_Jump_Chop")
	await get_tree().create_timer(0.8).timeout

	if is_dead:
		can_attack = true
		return

	var dist = (player.global_position - global_position).length()
	if dist <= attack_range:
		player.take_damage(attack_damage)

	await anim.animation_finished
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


# ------------------------------------------------------
# 💥 Slam Attack (ท่าไม้ตาย)
# ------------------------------------------------------
func slam_attack():
	if is_dead:
		return

	print("💥 BOSS USES SLAM ATTACK!")
	anim.play("Slam_Attack")

	await get_tree().create_timer(0.7).timeout
	for body in slam_area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			body.take_damage(slam_damage)

	# เอฟเฟกต์เขย่าจอ (ถ้ามี)
	if boss_ui and boss_ui.has_method("flash_boss_bar"):
		boss_ui.flash_boss_bar(Color(1, 0.2, 0.2))

	await anim.animation_finished


# ------------------------------------------------------
# 🔥 เข้าสู่ Phase 2
# ------------------------------------------------------
func enter_phase2():
	in_phase2 = true
	move_speed *= 1.4
	attack_damage *= 1.5
	slam_interval *= 0.7
	anim.play("Roar")
	print("🔥 BOSS ENTERS RAGE MODE!")

	if boss_ui and boss_ui.has_method("flash_boss_bar"):
		boss_ui.flash_boss_bar(Color(1, 0.3, 0.3))


# ------------------------------------------------------
# 💢 โดนตี
# ------------------------------------------------------
func take_damage(amount: float, from_dir: Vector3 = Vector3.ZERO):
	if is_dead:
		return

	health -= amount
	anim.play("Hit_B")

	# ✅ ลดแรงเด้ง
	if from_dir != Vector3.ZERO:
		from_dir.y = 0
		knockback_velocity = from_dir.normalized() * knockback_strength

	if boss_ui and boss_ui.has_method("update_boss_hp"):
		boss_ui.update_boss_hp(health)

	if health <= 0:
		die()


# ------------------------------------------------------
# ☠️ ตาย
# ------------------------------------------------------
func die():
	is_dead = true
	set_physics_process(false)
	anim.play("Death_C_Skeletons")

	if boss_ui and boss_ui.has_method("hide_boss_bar"):
		boss_ui.hide_boss_bar()

	# ✅ ให้ EXP เพิ่มเยอะกว่า enemy ปกติ
	if player and player.has_method("gain_exp"):
		player.gain_exp(300)

	await anim.animation_finished

	if spawner and spawner.has_method("return_enemy_to_pool"):
		spawner.return_enemy_to_pool(self)
	else:
		queue_free()
