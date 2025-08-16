extends Node3D

@export var chunk_size: int = 32
@export var render_distance: int = 6
@export var max_lod_level: int = 3

var chunks: Dictionary = {}
var player: Node3D
var terrain_material: StandardMaterial3D
var last_player_chunk: Vector2 = Vector2.INF

func _ready():
	player = get_parent().find_child("Player")
	setup_material()
	
func setup_material():
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color.WHITE
	terrain_material.roughness = 0.8
	terrain_material.metallic = 0.0
	
	var checker_texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	
	for x in range(64):
		for y in range(64):
			var checker_x = int(x / 8) % 2
			var checker_y = int(y / 8) % 2
			var color = Color(0.2, 0.8, 0.3) if (checker_x + checker_y) % 2 == 0 else Color(0.1, 0.5, 0.2)
			image.set_pixel(x, y, color)
	
	checker_texture.set_image(image)
	terrain_material.albedo_texture = checker_texture

func _process(_delta):
	if player:
		var current_chunk = world_to_chunk(player.global_position)
		if current_chunk != last_player_chunk:
			update_terrain()
			last_player_chunk = current_chunk

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
	var lod_level = min(int(distance_to_player / 2), max_lod_level)
	
	var static_body = StaticBody3D.new()
	var mesh_instance = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	var mesh = generate_terrain_mesh(chunk_pos, lod_level)
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	
	var shape = mesh.create_trimesh_shape()
	collision_shape.shape = shape
	
	static_body.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	
	add_child(static_body)
	chunks[chunk_key] = static_body

func generate_terrain_mesh(chunk_pos: Vector2, lod_level: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	var step = 1 << lod_level
	var resolution = chunk_size / step
	
	vertices.resize((resolution + 1) * (resolution + 1))
	normals.resize((resolution + 1) * (resolution + 1))
	uvs.resize((resolution + 1) * (resolution + 1))
	
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