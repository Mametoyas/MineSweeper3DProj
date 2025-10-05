extends Node3D

@export var enemy_scene: PackedScene
@export var pool_size: int = 50              # จำนวนศัตรูเริ่มต้นใน Pool
@export var spawn_interval: float = 3.0      # ระยะห่างการ spawn เริ่มต้น
@export var min_interval: float = 0.5        # เร็วสุดที่อนุญาต
@export var spawn_accel: float = 0.95        # ยิ่งนาน spawn ยิ่งเร็วขึ้น
@export var spawn_distance: float = 50.0     # ระยะ spawn โดยประมาณจาก Player
@export var max_active_enemies: int = 60     # จำกัดจำนวนศัตรูบนฉาก

@onready var path = $Path3D
@onready var path_follow = $Path3D/PathFollow3D
@onready var spawn_timer = $EnemySpawnTimer
@onready var player = get_tree().get_first_node_in_group("Player")

var enemy_pool: Array = []
var active_enemies: int = 0
var wave_count: int = 1   # นับรอบ wave


# ---------------------------
# 🧠 เตรียม Pool ตั้งแต่เริ่มเกม
# ---------------------------
func _ready():
	if not enemy_scene:
		push_warning("⚠️ enemy_scene ยังไม่ได้ตั้งค่าใน Inspector")
		return

	print("🛠 Initializing Enemy Pool...")

	for i in range(pool_size):
		var enemy = enemy_scene.instantiate()
		enemy.visible = false
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.add_to_group("Enemy")

		# ✅ เซ็ต spawner โดยตรง (ไม่ต้องเช็ก)
		enemy.spawner = self

		add_child(enemy)
		enemy_pool.append(enemy)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	add_to_group("Spawner")
	print("✅ Enemy pool created:", enemy_pool.size())


# ---------------------------
# 🔁 เรียกเมื่อ Timer หมดเวลา
# ---------------------------
func _on_spawn_timer_timeout():
	_spawn_enemy_from_pool()

	# ✅ ปรับความเร็วการ spawn แบบไดนามิก
	if active_enemies < max_active_enemies:
		spawn_interval = max(spawn_interval * spawn_accel, min_interval)
	else:
		spawn_interval = clamp(spawn_interval * 1.2, min_interval, 5.0)

	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()


# ---------------------------
# 💀 ดึงศัตรูว่างจาก Pool
# ---------------------------
func _spawn_enemy_from_pool():
	if not player:
		return

	if active_enemies >= max_active_enemies:
		return  # ถ้าเต็มแล้วไม่ spawn เพิ่ม

	for enemy in enemy_pool:
		if not enemy.visible and is_instance_valid(enemy):
			# ✅ สุ่มตำแหน่งบน Path3D รอบ Player
			path_follow.progress_ratio = randf()
			var pos = path_follow.global_position
			var random_offset = Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
			enemy.global_position = pos + random_offset

			# ✅ รีเซ็ตสถานะ Enemy ก่อนใช้งานใหม่
			if enemy.has_method("reset_state"):
				enemy.reset_state()

			enemy.visible = true
			enemy.set_physics_process(true)
			enemy.set_process(true)
			active_enemies += 1
			return

	# ✅ ถ้าไม่มีศัตรูว่าง → ขยาย Pool (จำกัดสูงสุด)
	if enemy_pool.size() < 100:
		var new_enemy = enemy_scene.instantiate()
		new_enemy.visible = true
		new_enemy.spawner = self  # ✅ เซ็ต spawner ตรง ๆ
		add_child(new_enemy)
		enemy_pool.append(new_enemy)
		active_enemies += 1
		print("⚙️ Pool expanded to:", enemy_pool.size())


# ---------------------------
# 🔄 คืนศัตรูเข้าพูล (เรียกจาก enemy.gd)
# ---------------------------
func return_enemy_to_pool(enemy):
	if not is_instance_valid(enemy):
		return

	if enemy in enemy_pool:
		enemy.visible = false
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.global_position = Vector3.ZERO
		active_enemies = max(active_enemies - 1, 0)
