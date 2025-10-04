extends CharacterBody3D

@export var move_speed: float = 2.5
@export var health: int = 40
@export var attack_damage: int = 10
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2

@onready var anim = $Rig/AnimationPlayer
@onready var attack_area = $AttackArea

var player: CharacterBody3D = null
var can_attack = true
var is_dead = false

# ----- Knockback -----
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_strength: float = 6.0
var knockback_friction: float = 10.0


func _ready():
	player = get_tree().get_first_node_in_group("Player")


func _physics_process(delta):
	if is_dead:
		return
	
	if not player:
		anim.play("Idle_Combat")
		return

	var dir = (player.global_position - global_position)
	dir.y = 0
	var distance = dir.length()

	# ✅ ถ้ามีแรง knockback ให้ใช้ก่อน
	if knockback_velocity.length() > 0.1:
		velocity = knockback_velocity
		move_and_slide()

		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
		return  # ขณะเด้ง ไม่เดินหรือโจมตี

	# ✅ ถ้ายังไม่ถึงระยะโจมตี → เดินเข้าหา
	if distance > attack_range:
		anim.play("Walking_D_Skeletons")
		dir = dir.normalized()
		var target_rot = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 8)
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_and_slide()
		if can_attack:
			attack()


func attack():
	can_attack = false
	anim.play("1H_Melee_Attack_Jump_Chop")

	# ✅ รอช่วงฟันถึง (0.6 วิ)
	await get_tree().create_timer(0.6).timeout

	# ถ้าตายหรือถูกขัดระหว่างตี → ยกเลิก
	if is_dead or not anim.is_playing():
		can_attack = true
		return

	# ✅ ตรวจว่าผู้เล่นยังอยู่ในระยะตอนฟันถึงไหม
	if player and not is_dead:
		var dist = (player.global_position - global_position).length()
		if dist <= attack_range:
			player.take_damage(attack_damage)

	await anim.animation_finished
	can_attack = true


func take_damage(amount, from_dir: Vector3 = Vector3.ZERO):
	if is_dead:
		return
	
	health -= amount
	print("Enemy HP:", health)
	anim.play("Hit_B")

	# ✅ Knockback
	if from_dir != Vector3.ZERO:
		knockback_velocity = from_dir.normalized() * knockback_strength

	if health <= 0:
		die()


func die():
	is_dead = true
	anim.play("Death_C_Skeletons")

	# ✅ ให้ EXP แก่ผู้เล่น
	if player and player.has_method("gain_exp"):
		player.gain_exp(30)

	await anim.animation_finished
	queue_free()
