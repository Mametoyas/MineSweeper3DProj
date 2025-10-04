extends Node3D

@export var enemy_scene: PackedScene
@export var initial_spawn_interval := 5.0   # เริ่มแรกสปอนทุก 5 วิ
@export var min_spawn_interval := 1.0        # เร็วสุดคือทุก 1 วิ
@export var spawn_acceleration := 0.95       # ทุกครั้งลดเวลาลง 5%
@export var enemies_per_wave := 1            # เริ่มแรกเกิดทีละ 1 ตัว
@export var max_enemies_per_wave := 20        # มากสุดต่อครั้ง

@onready var path = $Path3D
@onready var path_follow = $Path3D/PathFollow3D
@onready var spawn_timer = $EnemySpawnTimer

func _ready():
	spawn_timer.wait_time = initial_spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	for i in range(enemies_per_wave):
		spawn_enemy()

	# ✅ ค่อย ๆ เพิ่มความเร็วในการสปอน
	spawn_timer.wait_time = max(min_spawn_interval, spawn_timer.wait_time * spawn_acceleration)

	# ✅ เพิ่มจำนวนศัตรูต่อ wave ทีละนิด (ไม่เกิน max)
	if enemies_per_wave < max_enemies_per_wave:
		enemies_per_wave += 0.2

	spawn_timer.start()

func spawn_enemy():
	if not enemy_scene:
		return

	path_follow.progress_ratio = randf()
	var spawn_position = path_follow.global_position

	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position
	print("Spawned enemy at:", spawn_position)
