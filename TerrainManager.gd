extends Node3D

@export var chunk_size: int = 32
@export var render_distance: int = 15
@export var max_lod_level: int = 3

var chunks: Dictionary = {}
var player: Node3D
var terrain_material: StandardMaterial3D
var last_player_chunk: Vector2 = Vector2.INF
var update_timer: float = 0.0
var update_frequency: float = 0.5

func _ready():
	player = get_parent().find_child("Player")
	setup_material()
	
func setup_material():
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color.WHITE
	terrain_material.roughness = 0.8
	terrain_material.metallic = 0.0
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_material.uv1_scale = Vector3(8.0, 8.0, 8.0)  # Increase tiling
	
	var grass_texture = load("res://grass_checkered.tga")
	terrain_material.albedo_texture = grass_texture

func _process(delta):
	if player:
		update_timer += delta
		if update_timer >= update_frequency:
			var current_chunk = world_to_chunk(player.global_position)
			if current_chunk.distance_to(last_player_chunk) > 1:
				update_terrain()
				last_player_chunk = current_chunk
			update_timer = 0.0

func update_terrain():
	var player_chunk = world_to_chunk(player.global_position)
	
	var chunks_to_remove = []
	for chunk_key in chunks.keys():
		var chunk_pos = str_to_var("Vector2" + chunk_key)
		if chunk_pos.distance_to(player_chunk) > render_distance:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		remove_chunk(chunk_key)
	
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in chunks:
				create_chunk(chunk_pos)

func world_to_chunk(world_pos: Vector3) -> Vector2:
	return Vector2(floor(world_pos.x / chunk_size), floor(world_pos.z / chunk_size))

func create_chunk(chunk_pos: Vector2):
	var chunk_key = str(chunk_pos)
	var distance_to_player = chunk_pos.distance_to(world_to_chunk(player.global_position))
	var lod_level = min(int(distance_to_player / 3), max_lod_level)
	
	var static_body = StaticBody3D.new()
	var mesh_instance = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	var mesh = generate_terrain_mesh(chunk_pos, lod_level)
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	
	# Performance optimizations
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = 500.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	
	# Only add collision for close chunks
	if distance_to_player < 4:
		var shape = mesh.create_trimesh_shape()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
	
	static_body.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	static_body.add_child(mesh_instance)
	
	add_child(static_body)
	chunks[chunk_key] = static_body

func generate_terrain_mesh(chunk_pos: Vector2, lod_level: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	# Exponential LOD reduction for better performance
	var step = 1 << (lod_level + 1)
	step = max(step, 1)
	var resolution = max(chunk_size / step, 2)
	
	var vertex_count = (resolution + 1) * (resolution + 1)
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	
	var vertex_index = 0
	for x in range(resolution + 1):
		for z in range(resolution + 1):
			var world_x = chunk_pos.x * chunk_size + x * step
			var world_z = chunk_pos.y * chunk_size + z * step
			var height = get_height_at(world_x, world_z)
			
			vertices[vertex_index] = Vector3(x * step, height, z * step)
			normals[vertex_index] = Vector3.UP
			uvs[vertex_index] = Vector2(float(x) / resolution, float(z) / resolution)
			vertex_index += 1
	
	indices.resize(resolution * resolution * 6)
	var index_pos = 0
	for x in range(resolution):
		for z in range(resolution):
			var i = x * (resolution + 1) + z
			
			indices[index_pos] = i
			indices[index_pos + 1] = i + resolution + 1
			indices[index_pos + 2] = i + 1
			
			indices[index_pos + 3] = i + 1
			indices[index_pos + 4] = i + resolution + 1
			indices[index_pos + 5] = i + resolution + 2
			
			index_pos += 6
	
	var mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return mesh

func get_height_at(x: float, z: float) -> float:
	var height = 0.0
	
	height += sin(x * 0.005) * cos(z * 0.005) * 8.0
	height += sin(x * 0.01) * cos(z * 0.01) * 4.0
	height += sin(x * 0.03) * cos(z * 0.03) * 2.0
	height += sin(x * 0.08) * cos(z * 0.08) * 0.5
	
	var ridge = abs(sin(x * 0.002)) * 6.0
	var valley = -abs(cos(z * 0.003)) * 4.0
	
	height += ridge + valley
	
	return height

func remove_chunk(chunk_key: String):
	if chunk_key in chunks:
		chunks[chunk_key].queue_free()
		chunks.erase(chunk_key)
