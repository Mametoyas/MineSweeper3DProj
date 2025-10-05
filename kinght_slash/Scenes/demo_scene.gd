extends Node3D

# --- 🔧 CONFIG --- #
@export var enemy_scenes: Array[PackedScene] = []
@export var pool_size: int = 40
@export var spawn_interval: float = 3.0
@export var min_interval: float = 0.5
@export var spawn_accel: float = 0.95
@export var max_active_enemies: int = 40

@onready var path = $Path3D
@onready var path_follow = $Path3D/PathFollow3D
@onready var spawn_timer = $EnemySpawnTimer
@onready var player = get_tree().get_first_node_in_group("Player")

var enemy_pool: Array = []
var active_enemies: int = 0
var wave_count: int = 1


# ---------------------------
# 🧠 เตรียม Pool ตั้งแต่เริ่มเกม
# ---------------------------
func _ready():
	if enemy_scenes.is_empty():
		push_warning("⚠️ ต้องใส่ enemy_scenes อย่างน้อย 1 scene ใน Inspector!")
		return

	print("🛠 Initializing Enemy Pool...")

	for i in range(pool_size):
		var enemy_scene = enemy_scenes.pick_random()  # ✅ สุ่มชนิดศัตรู
		var enemy = enemy_scene.instantiate()
		enemy.visible = false
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.add_to_group("Enemy")
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
	var enemies_to_spawn = randi_range(1, 3)  # ✅ สุ่ม 1–3 ตัว
	for i in range(enemies_to_spawn):
		_spawn_enemy_from_pool()

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
		return

	# ✅ หา enemy ที่ว่างก่อน
	for enemy in enemy_pool:
		if not enemy.visible and is_instance_valid(enemy):
			path_follow.progress_ratio = randf()
			var pos = path_follow.global_position
			enemy.global_position = pos

			if enemy.has_method("reset_state"):
				enemy.reset_state()

			enemy.visible = true
			enemy.set_physics_process(true)
			enemy.set_process(true)
			active_enemies += 1
			return

	# ✅ ถ้าไม่มีใน pool → ขยายเพิ่มพร้อมสุ่มประเภท
	if enemy_pool.size() < 100:
		var new_enemy_scene = enemy_scenes.pick_random()
		var new_enemy = new_enemy_scene.instantiate()
		new_enemy.visible = true
		new_enemy.spawner = self
		add_child(new_enemy)
		enemy_pool.append(new_enemy)
		active_enemies += 1
		print("⚙️ Pool expanded to:", enemy_pool.size())


# ---------------------------
# 🔄 คืนศัตรูเข้าพูล
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
