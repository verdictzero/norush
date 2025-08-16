extends CharacterBody3D

@export var base_speed: float = 0.5
@export var max_speed: float = 15.0
@export var acceleration: float = 2.0
@export var stress_buildup_rate: float = 1.0
@export var stress_decay_rate: float = 0.3
@export var health_damage_rate: float = 5.0
@export var health_regen_rate: float = 2.0
@export var max_lives: int = 10

var current_speed: float = 0.5
var stress_level: float = 0.0
var punishment_timer: float = 0.0
var health: float = 100.0
var lives: int = 10
var is_game_over: bool = false
var debug_mode: bool = false
var debug_input_buffer: String = ""
var distance_travelled: float = 0.0
var last_position: Vector3
var game_time: float = 0.0
var current_score: float = 0.0

@onready var mesh_instance = $MeshInstance3D
@onready var explosion_system = $ExplosionSystem
@onready var high_score_manager = get_node("../HighScoreManager")

func _ready():
	lives = max_lives
	last_position = global_position

func _physics_process(delta):
	if is_game_over:
		return
	
	handle_debug_input()
	handle_input(delta)
	
	if not debug_mode:
		update_stress(delta)
		update_health(delta)
		apply_punishment(delta)
	
	move_and_slide()
	update_distance_travelled()
	update_score(delta)

func handle_input(delta):
	var input_vector = Vector3()
	
	if Input.is_action_pressed("move_forward"):
		input_vector.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_vector.z += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	if input_vector.length() > 0:
		var target_speed = max_speed * 5.0 if debug_mode else max_speed
		current_speed = min(current_speed + acceleration * delta, target_speed)
		input_vector = input_vector.normalized()
		velocity.x = input_vector.x * current_speed
		velocity.z = input_vector.z * current_speed
	else:
		current_speed = move_toward(current_speed, base_speed, acceleration * delta)
		velocity.x = move_toward(velocity.x, 0, current_speed * 2 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 2 * delta)
	
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

func update_stress(delta):
	var speed_ratio = current_speed / max_speed
	
	if speed_ratio > 0.3:
		stress_level += stress_buildup_rate * speed_ratio * delta
	else:
		stress_level = move_toward(stress_level, 0, stress_decay_rate * delta)
	
	stress_level = clamp(stress_level, 0, 10)

func apply_punishment(delta):
	if stress_level > 3.0:
		var shake_intensity = (stress_level - 3.0) * 0.1
		var shake_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		mesh_instance.position = shake_offset
		
		var red_intensity = clamp((stress_level - 3.0) / 7.0, 0, 1)
		var material = mesh_instance.get_surface_override_material(0)
		if not material:
			material = StandardMaterial3D.new()
			mesh_instance.set_surface_override_material(0, material)
		material.albedo_color = Color.WHITE.lerp(Color.RED, red_intensity)
	else:
		mesh_instance.position = Vector3.ZERO
		var material = mesh_instance.get_surface_override_material(0)
		if material:
			material.albedo_color = Color.WHITE
	
	if stress_level >= 8.0:
		print("CRITICAL STRESS! EXPLOSION IMMINENT!")
		explode()

func update_health(delta):
	var speed_ratio = current_speed / max_speed
	
	if speed_ratio > 0.6:
		var damage_multiplier = (speed_ratio - 0.6) * 2.5
		health -= health_damage_rate * damage_multiplier * delta
	elif stress_level < 2.0 and speed_ratio < 0.3:
		health += health_regen_rate * delta
	
	health = clamp(health, 0, 100)
	
	if health <= 0:
		print("Health depleted! EXPLOSION!")
		explode()

func explode():
	print("💥 BOOM! You pushed too hard and exploded! 💥")
	
	explosion_system.create_explosion(global_position)
	
	visible = false
	current_speed = 0
	velocity = Vector3.ZERO
	lives -= 1
	
	if lives <= 0:
		game_over()
		return
	
	await get_tree().create_timer(3.0).timeout
	
	print("Respawning... Lives remaining: %d" % lives)
	global_position = Vector3(0, 5, 0)
	health = 100
	stress_level = 0
	visible = true

func game_over():
	print("💀 GAME OVER! You've run out of lives! 💀")
	is_game_over = true
	visible = false
	current_speed = 0
	velocity = Vector3.ZERO
	
	if high_score_manager.is_high_score(current_score):
		var rank = high_score_manager.add_score("Player", current_score, distance_travelled, game_time)
		print("🏆 NEW HIGH SCORE! Rank #%d - Score: %.1f" % [rank, current_score])
	else:
		print("💯 Final Score: %.1f (Distance: %.1fm, Time: %.1fs)" % [current_score, distance_travelled, game_time])
	
	await get_tree().create_timer(5.0).timeout
	
	print("Restarting game...")
	restart_game()

func restart_game():
	lives = max_lives
	health = 100
	stress_level = 0
	distance_travelled = 0.0
	game_time = 0.0
	current_score = 0.0
	is_game_over = false
	global_position = Vector3(0, 5, 0)
	last_position = global_position
	visible = true

func handle_debug_input():
	pass

func _input(event):
	if event is InputEventKey and event.pressed and event.unicode > 0:
		var char_string = String.chr(event.unicode).to_lower()
		if char_string.length() == 1 and char_string >= "a" and char_string <= "z":
			debug_input_buffer += char_string
			if debug_input_buffer.length() > 5:
				debug_input_buffer = debug_input_buffer.substr(1)
			
			if debug_input_buffer == "iddqd":
				debug_mode = !debug_mode
				debug_input_buffer = ""
				if debug_mode:
					print("🚀 DEBUG MODE ACTIVATED! GODLIKE SPEED ENABLED!")
					mesh_instance.modulate = Color.CYAN
				else:
					print("🐌 Debug mode disabled. Back to No Rush!")
					mesh_instance.modulate = Color.WHITE

func update_distance_travelled():
	var current_pos = Vector3(global_position.x, 0, global_position.z)
	var last_pos = Vector3(last_position.x, 0, last_position.z)
	distance_travelled += current_pos.distance_to(last_pos)
	last_position = global_position

func update_score(delta):
	game_time += delta
	if game_time > 0:
		current_score = (distance_travelled / game_time) * 100.0
