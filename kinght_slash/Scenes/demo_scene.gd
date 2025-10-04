extends Node3D

@export var enemy_scene: PackedScene
@onready var path = $Path3D
@onready var path_follow = $Path3D/PathFollow3D
@onready var spawn_timer = $EnemySpawnTimer

func _ready():
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout():
	spawn_enemy()
	spawn_timer.start()  # เริ่มจับเวลาใหม่

func spawn_enemy():
	if not enemy_scene:
		print("No enemy scene assigned!")
		return

	# ✅ สุ่มตำแหน่งบนเส้น Path3D
	path_follow.progress_ratio = randf()
	var spawn_position = path_follow.global_position

	# ✅ สร้าง enemy
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position

	print("Spawned enemy at:", spawn_position)
