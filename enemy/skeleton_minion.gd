extends CharacterBody3D

# ---------- CONFIG ---------- #
@export var move_speed: float = 2.5
@export var max_health: int = 40
@export var attack_damage: int = 10
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2
@export var active_distance: float = 80.0

# ---------- REFERENCES ---------- #
@onready var anim: AnimationPlayer = $Rig/AnimationPlayer
@onready var attack_area: Area3D = $AttackArea
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("Player")

# ---------- STATE ---------- #
var health: int = 0
var can_attack: bool = true
var is_dead: bool = false
var spawner: Node = null  # สำหรับคืนกลับ Pool

# ---------- Knockback ---------- #
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_strength: float = 6.0
var knockback_friction: float = 10.0

@onready var sfx_die = $Rig/sound/die

# ------------------------------------------------------
# 🧠 เริ่มต้นหรือรีเซ็ตใหม่ตอนดึงจาก Pool
# ------------------------------------------------------
func reset_state():
	is_dead = false
	can_attack = true
	health = max_health
	velocity = Vector3.ZERO
	global_position.y = 3  # หรือปรับให้อยู่ระดับพื้นจริง
	knockback_velocity = Vector3.ZERO
	attack_area.monitoring = true
	set_physics_process(true)
	visible = true
	anim.play("Idle_Combat")


# ------------------------------------------------------
# 🦴 ฟิสิกส์การเคลื่อนที่และต่อสู้ (แก้ลอย)
# ------------------------------------------------------
func _physics_process(delta):
	if is_dead or not player:
		return

	# ✅ เพิ่มแรงโน้มถ่วงพื้นฐานให้ศัตรู
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var dir = player.global_position - global_position
	dir.y = 0
	var distance = dir.length()

	# ✅ ถ้ามีแรง Knockback
	if knockback_velocity.length() > 0.1:
		# ใช้เฉพาะแกน XZ ของ knockback (ไม่ยุ่งกับ Y)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		# ลดแรงเด้งลงเรื่อย ๆ
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
		return

	# ✅ ถ้าอยู่ไกลเกิน active_distance → Idle
	if distance > active_distance:
		anim.play("Idle_Combat")
		move_and_slide()
		return

	# ✅ ถ้าอยู่ในระยะโจมตี
	if distance <= attack_range:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if can_attack:
			attack()
	else:
		# ✅ เดินเข้าหา Player
		anim.play("Walking_D_Skeletons")
		dir = dir.normalized()
		var target_rot = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 8)
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		move_and_slide()

# ------------------------------------------------------
# ⚔️ ฟังก์ชันโจมตี
# ------------------------------------------------------
func attack():
	can_attack = false
	anim.play("1H_Melee_Attack_Jump_Chop")

	await get_tree().create_timer(0.6).timeout  # จังหวะฟัน

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
# 💥 ฟังก์ชันเมื่อโดนตี
# ------------------------------------------------------
func take_damage(amount, from_dir: Vector3 = Vector3.ZERO):
	if is_dead:
		return
	
	health -= amount
	anim.play("Hit_B")

	# ✅ กันลอยขึ้นฟ้า
	if from_dir != Vector3.ZERO:
		from_dir.y = 0
		knockback_velocity = from_dir.normalized() * knockback_strength

	if health <= 0:
		die()

# ------------------------------------------------------
# ☠️ ฟังก์ชันตอนตาย
# ------------------------------------------------------
func die():
	sfx_die.play()
	is_dead = true
	anim.play("Death_C_Skeletons")
	set_physics_process(false)
	attack_area.monitoring = false

	# ✅ ให้ EXP แก่ Player
	if player and player.has_method("gain_exp"):
		player.gain_exp(30)

	await anim.animation_finished

	# ✅ คืนเข้าพูลแทน queue_free()
	if spawner and spawner.has_method("return_enemy_to_pool"):
		spawner.return_enemy_to_pool(self)
	elif has_meta("spawner"):
		get_meta("spawner").return_enemy_to_pool(self)
	else:
		queue_free()
