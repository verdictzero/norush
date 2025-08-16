extends RigidBody3D

@export var torque_strength: float = 3.0
@export var max_torque: float = 50.0
@export var max_speed: float = 15.0
@export var max_angular_velocity: float = 8.0
@export var rolling_friction: float = 0.92
@export var stress_buildup_rate: float = 0.3
@export var stress_decay_rate: float = 0.3
@export var health_damage_rate: float = 5.0
@export var health_regen_rate: float = 2.0
@export var max_lives: int = 10

var current_speed: float = 0.0
var stress_level: float = 0.0
var health: float = 100.0
var lives: int = 10
var is_game_over: bool = false
var debug_mode: bool = false
var debug_input_buffer: String = ""
var distance_travelled: float = 0.0
var last_position: Vector3
var game_time: float = 0.0
var current_score: float = 0.0
var flash_timer: float = 0.0

@onready var mesh_instance = $FleshCube
@onready var explosion_system = $ExplosionSystem
@onready var high_score_manager = get_node("../HighScoreManager")

func _ready():
	lives = max_lives
	last_position = global_position
	# Set RigidBody3D properties for heavy cube
	gravity_scale = 1.5
	mass = 5.0
	linear_damp = 0.1
	angular_damp = 0.3
	
	# Ensure player has collision detection
	setup_collision_if_needed()

func _physics_process(delta):
	if is_game_over:
		return
	
	handle_debug_input()
	handle_input(delta)
	
	if not debug_mode:
		update_stress(delta)
		update_health(delta)
		apply_punishment(delta)
	
	update_distance_travelled()
	update_score(delta)
	check_terrain_collision()

func setup_collision_if_needed():
	# Check if player already has a collision shape
	var has_collision = false
	for child in get_children():
		if child is CollisionShape3D:
			has_collision = true
			break
		elif child is RigidBody3D and child.get_child_count() > 0:
			# Check if flesh cube child has collision
			for grandchild in child.get_children():
				if grandchild is CollisionShape3D:
					has_collision = true
					break
	
	# If no collision found, add a sphere collision for the player
	if not has_collision:
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.5
		collision_shape.shape = sphere_shape
		add_child(collision_shape)
		print("Added collision shape to player")

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
		input_vector = input_vector.normalized()
		
		# Apply torque for tumbling motion
		var torque_multiplier = 5.0 if debug_mode else 1.0
		var torque_force = torque_strength * torque_multiplier
		
		# Roll forward/backward (rotate around X axis)
		if input_vector.z != 0:
			apply_torque(Vector3(input_vector.z * torque_force, 0, 0))
		
		# Roll left/right (rotate around Z axis) 
		if input_vector.x != 0:
			apply_torque(Vector3(0, 0, -input_vector.x * torque_force))
		
		# Calculate current speed from velocity
		current_speed = linear_velocity.length()
		
		# Gradually limit angular velocity to prevent clipping through terrain
		var current_angular_speed = angular_velocity.length()
		if current_angular_speed > max_angular_velocity:
			var limit_factor = max_angular_velocity / current_angular_speed
			angular_velocity = angular_velocity.lerp(angular_velocity * limit_factor, 0.1)
	else:
		# Apply rolling friction
		angular_velocity *= rolling_friction
		linear_velocity *= rolling_friction
		current_speed = linear_velocity.length()

func update_stress(delta):
	var speed_ratio = current_speed / max_speed
	
	if speed_ratio > 0.3:
		stress_level += stress_buildup_rate * speed_ratio * delta
	else:
		stress_level = move_toward(stress_level, 0, stress_decay_rate * delta)
	
	stress_level = clamp(stress_level, 0, 10)

func apply_punishment(delta):
	flash_timer += delta
	
	if stress_level > 3.0:
		# Flash red based on stress level
		var flash_frequency = stress_level * 2.0  # Faster flashing with higher stress
		var flash_intensity = clamp((stress_level - 3.0) / 7.0, 0, 1)
		
		# Create flashing effect
		var flash_value = (sin(flash_timer * flash_frequency) + 1.0) * 0.5
		var red_color = Color.WHITE.lerp(Color.RED, flash_intensity * flash_value)
		apply_color_to_mesh(red_color)
	else:
		apply_color_to_mesh(Color.WHITE)
	
	if stress_level >= 8.0:
		print("CRITICAL STRESS! EXPLOSION IMMINENT!")
		explode()

func apply_color_to_mesh(color: Color):
	# Find and apply color to all MeshInstance3D children
	for child in mesh_instance.get_children():
		if child is MeshInstance3D:
			apply_material_color(child, color)
	
	# Also try to apply to the mesh_instance itself if it's a MeshInstance3D
	if mesh_instance is MeshInstance3D:
		apply_material_color(mesh_instance, color)

func apply_material_color(mesh_inst: MeshInstance3D, color: Color):
	if not mesh_inst.material_override:
		# Create a new material based on the existing one
		if mesh_inst.get_surface_override_material(0):
			mesh_inst.material_override = mesh_inst.get_surface_override_material(0).duplicate()
		else:
			mesh_inst.material_override = StandardMaterial3D.new()
		
		# Ensure nearest neighbor filtering for lofi effect
		if mesh_inst.material_override is StandardMaterial3D:
			var mat = mesh_inst.material_override as StandardMaterial3D
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	if mesh_inst.material_override is StandardMaterial3D:
		var mat = mesh_inst.material_override as StandardMaterial3D
		mat.albedo_color = color

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
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	lives -= 1
	
	if lives <= 0:
		game_over()
		return
	
	await get_tree().create_timer(3.0).timeout
	
	print("Respawning... Lives remaining: %d" % lives)
	global_position = Vector3(0, 5, 0)
	global_rotation = Vector3.ZERO
	health = 100
	stress_level = 0
	freeze = false
	visible = true

func game_over():
	print("💀 GAME OVER! You've run out of lives! 💀")
	is_game_over = true
	visible = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
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
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
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
					if mesh_instance:
						mesh_instance.modulate = Color.CYAN
				else:
					print("🐌 Debug mode disabled. Back to No Rush!")
					if mesh_instance:
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

func check_terrain_collision():
	# Get terrain height at current position
	var terrain_height = get_terrain_height_at(global_position.x, global_position.z)
	var min_y = terrain_height + 0.3  # Keep player 0.3 units above terrain
	
	# If player is below terrain, push them back up gently
	if global_position.y < min_y:
		var correction = min_y - global_position.y
		global_position.y += correction * 0.5  # Gradual correction
		# Only dampen vertical velocity, preserve horizontal movement
		if linear_velocity.y < 0:
			linear_velocity.y = max(linear_velocity.y * 0.8, -3.0)

func get_terrain_height_at(x: float, z: float) -> float:
	var height = 0.0
	
	height += sin(x * 0.005) * cos(z * 0.005) * 8.0
	height += sin(x * 0.01) * cos(z * 0.01) * 4.0
	height += sin(x * 0.03) * cos(z * 0.03) * 2.0
	height += sin(x * 0.08) * cos(z * 0.08) * 0.5
	
	var ridge = abs(sin(x * 0.002)) * 6.0
	var valley = -abs(cos(z * 0.003)) * 4.0
	
	height += ridge + valley
	
	return height
