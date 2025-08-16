extends Node3D

@export var spawn_distance: float = 80.0
@export var clusters_per_chunk: int = 3
@export var bushes_per_cluster: int = 5
@export var cluster_radius: float = 4.0
@export var min_scale: float = 0.6
@export var max_scale: float = 2.0

var spawned_bushes: Dictionary = {}
var player: Node3D
var bush_material: StandardMaterial3D
var update_timer: float = 0.0
var update_frequency: float = 1.0

func _ready():
	player = get_parent().find_child("Player")
	setup_bush_material()

func setup_bush_material():
	bush_material = StandardMaterial3D.new()
	var bush_texture = load("res://bush.tga")
	bush_material.albedo_texture = bush_texture
	bush_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bush_material.roughness = 1.0
	bush_material.metallic = 0.0
	bush_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bush_material.no_depth_test = false
	bush_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bush_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

func _process(delta):
	if player:
		update_timer += delta
		if update_timer >= update_frequency:
			update_bushes()
			update_timer = 0.0

func update_bushes():
	var player_pos = player.global_position
	var chunk_size = 32.0
	
	var bushes_to_remove = []
	for chunk_key in spawned_bushes.keys():
		var chunk_pos = str_to_var("Vector2" + chunk_key)
		var world_pos = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
		if world_pos.distance_to(player_pos) > spawn_distance:
			bushes_to_remove.append(chunk_key)
	
	for chunk_key in bushes_to_remove:
		remove_bushes_in_chunk(chunk_key)
	
	var player_chunk = Vector2(floor(player_pos.x / chunk_size), floor(player_pos.z / chunk_size))
	var spawn_radius = int(spawn_distance / chunk_size)
	
	for x in range(player_chunk.x - spawn_radius, player_chunk.x + spawn_radius + 1):
		for z in range(player_chunk.y - spawn_radius, player_chunk.y + spawn_radius + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in spawned_bushes:
				spawn_bushes_in_chunk(chunk_pos)

func spawn_bushes_in_chunk(chunk_pos: Vector2):
	var chunk_key = str(chunk_pos)
	var chunk_bushes = []
	var chunk_size = 32.0
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_key + "bushes")
	
	for cluster_i in range(clusters_per_chunk):
		var cluster_center_x = rng.randf_range(cluster_radius, chunk_size - cluster_radius)
		var cluster_center_z = rng.randf_range(cluster_radius, chunk_size - cluster_radius)
		
		for bush_i in range(bushes_per_cluster):
			var mesh_instance = MeshInstance3D.new()
			
			var quad_mesh = QuadMesh.new()
			quad_mesh.size = Vector2(1.5, 1.0)
			
			mesh_instance.mesh = quad_mesh
			mesh_instance.material_override = bush_material
			
			var distance_from_center = rng.randf_range(0, cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var bush_x = cluster_center_x + cos(angle) * distance_from_center
			var bush_z = cluster_center_z + sin(angle) * distance_from_center
			
			var world_x = chunk_pos.x * chunk_size + bush_x
			var world_z = chunk_pos.y * chunk_size + bush_z
			var height = get_terrain_height_at(world_x, world_z)
			
			var scale_factor = lerp(max_scale, min_scale, distance_from_center / cluster_radius)
			scale_factor *= rng.randf_range(0.8, 1.2)
			
			mesh_instance.position = Vector3(world_x, height + (scale_factor * 0.3), world_z)
			mesh_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
			
			mesh_instance.rotation_degrees.y = rng.randf_range(0, 360)
			
			add_child(mesh_instance)
			chunk_bushes.append(mesh_instance)
	
	spawned_bushes[chunk_key] = chunk_bushes

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

func remove_bushes_in_chunk(chunk_key: String):
	if chunk_key in spawned_bushes:
		for bush in spawned_bushes[chunk_key]:
			bush.queue_free()
		spawned_bushes.erase(chunk_key)