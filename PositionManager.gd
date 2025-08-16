extends Node

# Manages floating point precision by shifting the world when player gets too far from origin
# This prevents floating point precision issues in infinite worlds

@export var shift_threshold: float = 1000.0  # Distance from origin before shifting
@export var shift_amount: float = 500.0     # How much to shift back towards origin

var player: RigidBody3D
var terrain_manager: Node3D
var vegetation_spawner: Node3D
var mountain_renderer: Node3D
var camera: Node3D
var world_offset: Vector3 = Vector3.ZERO

signal world_shifted(offset: Vector3)

func _ready():
	# Find all the systems that need to be shifted
	var main = get_parent()
	player = main.find_child("Player")
	terrain_manager = main.find_child("TerrainManager")
	vegetation_spawner = main.find_child("VegetationSpawner")
	mountain_renderer = main.find_child("MountainRenderer")
	camera = main.find_child("ThirdPersonCamera")
	
	# Connect to world_shifted signal for any systems that need it
	world_shifted.connect(_on_world_shifted)

func _process(delta):
	if not player:
		return
	
	var player_pos = player.global_position
	var distance_from_origin = Vector2(player_pos.x, player_pos.z).length()
	
	# Check if we need to shift the world
	if distance_from_origin > shift_threshold:
		shift_world()

func shift_world():
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Calculate shift amount to bring player closer to origin
	var horizontal_distance = Vector2(player_pos.x, player_pos.z)
	var shift_direction = horizontal_distance.normalized()
	var shift_vector_2d = shift_direction * shift_amount
	var shift_vector = Vector3(shift_vector_2d.x, 0, shift_vector_2d.y)
	
	print("Shifting world by: ", shift_vector)
	
	# Update world offset for tracking
	world_offset += shift_vector
	
	# Shift all world objects
	shift_player(-shift_vector)
	shift_terrain(-shift_vector)
	shift_vegetation(-shift_vector)
	shift_camera(-shift_vector)
	
	# Emit signal for any other systems that need to know about the shift
	world_shifted.emit(shift_vector)

func shift_player(offset: Vector3):
	if player:
		player.global_position += offset

func shift_terrain(offset: Vector3):
	if terrain_manager:
		# Terrain manager generates procedurally, so we just need to shift its reference point
		if terrain_manager.has_method("shift_origin"):
			terrain_manager.shift_origin(offset)
		else:
			# Fallback: shift the node itself
			terrain_manager.global_position += offset

func shift_vegetation(offset: Vector3):
	if vegetation_spawner:
		# Vegetation spawner generates procedurally, so we need to shift its spawned chunks
		if vegetation_spawner.has_method("shift_chunks"):
			vegetation_spawner.shift_chunks(offset)
		else:
			# Fallback: shift the node itself  
			vegetation_spawner.global_position += offset

func shift_camera(offset: Vector3):
	if camera:
		camera.global_position += offset

func get_true_world_position(local_pos: Vector3) -> Vector3:
	# Returns the true world position accounting for all shifts
	return local_pos + world_offset

func get_local_position(world_pos: Vector3) -> Vector3:
	# Converts true world position to current local position
	return world_pos - world_offset

func _on_world_shifted(offset: Vector3):
	# Handle any additional logic needed when world shifts
	pass