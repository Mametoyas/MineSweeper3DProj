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

func _ready():
	# หาผู้เล่นในซีน (ชื่อ node ต้องตรงกับ Player scene)
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

	if distance > attack_range:
		anim.play("Walking_D_Skeletons")
		dir = dir.normalized()
		
		# ✅ หมุนให้หันหน้าไปทางทิศที่เดิน
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

	# ✅ รอช่วง “จังหวะฟันถึง” (ปรับตาม animation)
	await get_tree().create_timer(0.6).timeout

	# ถ้าศัตรูตายก่อน หรือ animation ถูกขัด → ไม่ทำดาเมจ
	if is_dead or not anim.is_playing():
		can_attack = true
		return

	# ✅ เช็กว่าผู้เล่นยังอยู่ในระยะตอนฟันถึงไหม
	if player and not is_dead:
		var dist = (player.global_position - global_position).length()
		if dist <= attack_range:
			player.take_damage(attack_damage)

	# ✅ รอให้ animation เล่นจบก่อนเริ่มโจมตีใหม่
	await anim.animation_finished
	can_attack = true



func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	print("Enemy HP:", health)
	anim.play("Hit_B")  # ถ้ามีแอนิเมชันโดนตี
	
	if health <= 0:
		die()

func die():
	is_dead = true
	anim.play("Death_C_Skeletons")
	await anim.animation_finished
	queue_free()
