extends Node3D

# Mountain rendering for distant horizon
@export var mountain_distance: float = 500.0
@export var mountain_height: float = 80.0
@export var mountain_segments: int = 64
@export var mountain_layers: int = 3

var player: Node3D
var mountain_meshes: Array[MeshInstance3D] = []
var mountain_materials: Array[StandardMaterial3D] = []

func _ready():
	player = get_parent().find_child("Player")
	create_mountain_layers()

func create_mountain_layers():
	for layer in range(mountain_layers):
		var distance_multiplier = 1.0 + layer * 0.5
		var height_multiplier = 1.0 + layer * 0.3
		var alpha = 1.0 - (layer * 0.3)
		
		create_mountain_ring(
			mountain_distance * distance_multiplier,
			mountain_height * height_multiplier,
			alpha,
			layer
		)

func create_mountain_ring(distance: float, height: float, alpha: float, layer_index: int):
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Create circular mountain ring
	for i in range(mountain_segments + 1):
		var angle = (i * TAU) / mountain_segments
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		
		# Generate mountain height using multiple noise layers
		var mountain_height_here = generate_mountain_height(x, z, height)
		
		# Base vertex (at terrain level)
		vertices.append(Vector3(x, 0, z))
		normals.append(Vector3(0, 1, 0))
		uvs.append(Vector2(float(i) / mountain_segments, 0))
		
		# Peak vertex
		vertices.append(Vector3(x, mountain_height_here, z))
		normals.append(Vector3(0, 1, 0))
		uvs.append(Vector2(float(i) / mountain_segments, 1))
		
		# Create triangles (except for last segment)
		if i < mountain_segments:
			var base_idx = i * 2
			var next_base_idx = (i + 1) * 2
			
			# Triangle 1
			indices.append(base_idx)
			indices.append(next_base_idx)
			indices.append(base_idx + 1)
			
			# Triangle 2
			indices.append(base_idx + 1)
			indices.append(next_base_idx)
			indices.append(next_base_idx + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	var base_color = Color(0.4 + layer_index * 0.1, 0.3 + layer_index * 0.1, 0.6 + layer_index * 0.1, alpha)
	material.albedo_color = base_color
	material.roughness = 0.8
	material.metallic = 0.0
	material.flags_transparent = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material.no_depth_test = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	mesh_instance.material_override = material
	mesh_instance.name = "MountainLayer_" + str(layer_index)
	
	add_child(mesh_instance)
	mountain_meshes.append(mesh_instance)
	mountain_materials.append(material)

func generate_mountain_height(x: float, z: float, max_height: float) -> float:
	var height = 0.0
	
	# Large mountain ridges
	height += sin(x * 0.001) * cos(z * 0.0008) * max_height * 0.6
	height += sin(x * 0.0015) * cos(z * 0.0012) * max_height * 0.3
	
	# Medium details
	height += sin(x * 0.003) * cos(z * 0.0025) * max_height * 0.2
	height += sin(x * 0.005) * cos(z * 0.004) * max_height * 0.1
	
	# Ensure mountains are always above ground
	height = max(height, max_height * 0.3)
	
	return height

func _process(delta):
	if player:
		# Keep mountains centered on player
		var player_pos = player.global_position
		global_position = Vector3(player_pos.x, 0, player_pos.z)
		
		# Update fog tinting based on time of day (if day/night cycle exists)
		update_mountain_colors()

func update_mountain_colors():
	# Get time of day from DayNightCycle if it exists
	var day_night_cycle = get_parent().find_child("DayNightCycle")
	if day_night_cycle and day_night_cycle.has_method("get_current_time_normalized"):
		var time_normalized = day_night_cycle.get_current_time_normalized()
		update_colors_for_time(time_normalized)

func update_colors_for_time(time_normalized: float):
	for i in range(mountain_materials.size()):
		var material = mountain_materials[i]
		var layer_index = i
		
		# Color transitions based on time of day
		var base_color: Color
		
		if time_normalized < 0.25:  # Night
			base_color = Color(0.1, 0.1, 0.2, 0.8 - layer_index * 0.2)
		elif time_normalized < 0.4:  # Dawn
			base_color = Color(0.6, 0.3, 0.4, 0.9 - layer_index * 0.2)
		elif time_normalized < 0.6:  # Day
			base_color = Color(0.4 + layer_index * 0.1, 0.5 + layer_index * 0.1, 0.7 + layer_index * 0.1, 0.7 - layer_index * 0.15)
		elif time_normalized < 0.75:  # Dusk
			base_color = Color(0.8, 0.4, 0.3, 0.8 - layer_index * 0.2)
		else:  # Night
			base_color = Color(0.1, 0.1, 0.2, 0.8 - layer_index * 0.2)
		
		material.albedo_color = base_color