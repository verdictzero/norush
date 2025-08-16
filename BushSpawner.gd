extends Node3D

# General spawning settings
@export var spawn_distance: float = 80.0

# Bush settings
@export_group("Bush Settings")
@export var bush_clusters_per_chunk: int = 3
@export var bushes_per_cluster: int = 5
@export var bush_cluster_radius: float = 4.0
@export var bush_min_scale: float = 0.9
@export var bush_max_scale: float = 3.0

# Tree settings
@export_group("Tree Settings")
@export var tree_clusters_per_chunk: int = 3
@export var trees_per_cluster: int = 3
@export var tree_cluster_radius: float = 6.0
@export var tree_min_scale: float = 8.0
@export var tree_max_scale: float = 15.0
@export var tree_aspect_ratio: float = 2.0  # height/width ratio
@export var tree_collision_radius: float = 0.8

# Instancing optimization
var spawned_chunks: Dictionary = {}
var player: Node3D
var bush_material: StandardMaterial3D
var bush_mesh: QuadMesh
var tree_material: StandardMaterial3D
var tree_mesh: QuadMesh
var update_timer: float = 0.0
var update_frequency: float = 1.0

# Performance optimizations
@export var max_chunks_loaded: int = 50
@export var use_frustum_culling: bool = true
@export var cull_distance: float = 120.0

# Clump overlap prevention
var min_clump_separation: float = 8.0

func _ready():
	player = get_parent().find_child("Player")
	setup_materials()

func setup_materials():
	# Create bush mesh and material
	bush_mesh = QuadMesh.new()
	bush_mesh.size = Vector2(1.0, 1.0)
	
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
	bush_material.flags_unshaded = true
	bush_material.flags_do_not_receive_shadows = true
	bush_material.flags_disable_ambient_light = false
	
	# Create tree mesh and material with proper aspect ratio
	tree_mesh = QuadMesh.new()
	tree_mesh.size = Vector2(1.0, tree_aspect_ratio)  # Maintain aspect ratio
	
	tree_material = StandardMaterial3D.new()
	var tree_texture = load("res://fir_tree.tga")
	tree_material.albedo_texture = tree_texture
	tree_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tree_material.roughness = 1.0
	tree_material.metallic = 0.0
	tree_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tree_material.no_depth_test = false
	tree_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	tree_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tree_material.flags_unshaded = true
	tree_material.flags_do_not_receive_shadows = true
	tree_material.flags_disable_ambient_light = false

func _process(delta):
	if player:
		update_timer += delta
		if update_timer >= update_frequency:
			update_bushes()
			update_timer = 0.0

func update_bushes():
	var player_pos = player.global_position
	var chunk_size = 32.0
	
	# Performance: Limit total chunks and remove distant ones
	var chunks_to_remove = []
	var chunk_distances = []
	
	for chunk_key in spawned_chunks.keys():
		var chunk_pos = str_to_var("Vector2" + chunk_key)
		var world_pos = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
		var distance = world_pos.distance_to(player_pos)
		
		if distance > cull_distance:
			chunks_to_remove.append(chunk_key)
		else:
			chunk_distances.append({"key": chunk_key, "distance": distance})
	
	# Remove distant chunks first
	for chunk_key in chunks_to_remove:
		remove_chunk(chunk_key)
	
	# If we're still over the limit, remove furthest chunks
	if spawned_chunks.size() > max_chunks_loaded:
		chunk_distances.sort_custom(func(a, b): return a.distance > b.distance)
		var excess_chunks = spawned_chunks.size() - max_chunks_loaded
		for i in range(excess_chunks):
			remove_chunk(chunk_distances[i].key)
	
	var player_chunk = Vector2(floor(player_pos.x / chunk_size), floor(player_pos.z / chunk_size))
	var spawn_radius = int(spawn_distance / chunk_size)
	
	for x in range(player_chunk.x - spawn_radius, player_chunk.x + spawn_radius + 1):
		for z in range(player_chunk.y - spawn_radius, player_chunk.y + spawn_radius + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in spawned_chunks:
				spawn_vegetation_in_chunk(chunk_pos)

func spawn_vegetation_in_chunk(chunk_pos: Vector2):
	var chunk_key = str(chunk_pos)
	var chunk_size = 32.0
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_key + "vegetation")
	
	# Generate non-overlapping clump positions
	var clump_positions = generate_clump_positions(chunk_pos, chunk_size, rng)
	
	# Create container node for this chunk's vegetation
	var chunk_container = Node3D.new()
	chunk_container.name = "VegetationChunk_" + chunk_key
	
	# Spawn bush clumps
	spawn_bush_clumps(chunk_container, clump_positions.bush_clumps, chunk_pos, chunk_size, rng)
	
	# Spawn tree clumps with collision
	spawn_tree_clumps(chunk_container, clump_positions.tree_clumps, chunk_pos, chunk_size, rng)
	
	add_child(chunk_container)
	spawned_chunks[chunk_key] = chunk_container

func generate_clump_positions(chunk_pos: Vector2, chunk_size: float, rng: RandomNumberGenerator) -> Dictionary:
	var bush_clumps = []
	var tree_clumps = []
	var all_clumps = []
	
	# Generate tree clumps first (less common, larger)
	for i in range(tree_clusters_per_chunk):
		var attempts = 0
		while attempts < 20:  # Prevent infinite loops
			var center_x = rng.randf_range(tree_cluster_radius, chunk_size - tree_cluster_radius)
			var center_z = rng.randf_range(tree_cluster_radius, chunk_size - tree_cluster_radius)
			var center = Vector2(center_x, center_z)
			
			# Check if this position conflicts with existing clumps
			var valid = true
			for existing_clump in all_clumps:
				var distance = center.distance_to(existing_clump.center)
				var required_distance = existing_clump.radius + tree_cluster_radius + min_clump_separation
				if distance < required_distance:
					valid = false
					break
			
			if valid:
				var tree_clump = {"center": center, "radius": tree_cluster_radius, "type": "tree"}
				tree_clumps.append(tree_clump)
				all_clumps.append(tree_clump)
				break
			
			attempts += 1
	
	# Generate bush clumps
	for i in range(bush_clusters_per_chunk):
		var attempts = 0
		while attempts < 20:
			var center_x = rng.randf_range(bush_cluster_radius, chunk_size - bush_cluster_radius)
			var center_z = rng.randf_range(bush_cluster_radius, chunk_size - bush_cluster_radius)
			var center = Vector2(center_x, center_z)
			
			# Check if this position conflicts with existing clumps
			var valid = true
			for existing_clump in all_clumps:
				var distance = center.distance_to(existing_clump.center)
				var required_distance = existing_clump.radius + bush_cluster_radius + min_clump_separation
				if distance < required_distance:
					valid = false
					break
			
			if valid:
				var bush_clump = {"center": center, "radius": bush_cluster_radius, "type": "bush"}
				bush_clumps.append(bush_clump)
				all_clumps.append(bush_clump)
				break
			
			attempts += 1
	
	return {"bush_clumps": bush_clumps, "tree_clumps": tree_clumps}

func spawn_bush_clumps(container: Node3D, bush_clumps: Array, chunk_pos: Vector2, chunk_size: float, rng: RandomNumberGenerator):
	var total_bushes = bush_clumps.size() * bushes_per_cluster
	if total_bushes == 0:
		return
	
	# Create MultiMeshInstance3D for bushes
	var multi_mesh_instance = MultiMeshInstance3D.new()
	var multi_mesh = MultiMesh.new()
	
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = total_bushes
	multi_mesh.mesh = bush_mesh
	
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.material_override = bush_material
	multi_mesh_instance.visibility_range_begin = 0.0
	multi_mesh_instance.visibility_range_end = cull_distance
	multi_mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	
	var instance_index = 0
	
	for clump in bush_clumps:
		for bush_i in range(bushes_per_cluster):
			var distance_from_center = rng.randf_range(0, bush_cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var bush_x = clump.center.x + cos(angle) * distance_from_center
			var bush_z = clump.center.y + sin(angle) * distance_from_center
			
			var world_x = chunk_pos.x * chunk_size + bush_x
			var world_z = chunk_pos.y * chunk_size + bush_z
			var height = get_terrain_height_at(world_x, world_z)
			
			var scale_factor = lerp(bush_max_scale, bush_min_scale, distance_from_center / bush_cluster_radius)
			scale_factor *= rng.randf_range(0.8, 1.2)
			
			var transform = Transform3D()
			transform = transform.scaled(Vector3(scale_factor, scale_factor, scale_factor))
			transform = transform.rotated(Vector3.UP, deg_to_rad(rng.randf_range(0, 360)))
			transform.origin = Vector3(world_x, height + (scale_factor * 0.3), world_z)
			
			multi_mesh.set_instance_transform(instance_index, transform)
			instance_index += 1
	
	container.add_child(multi_mesh_instance)

func spawn_tree_clumps(container: Node3D, tree_clumps: Array, chunk_pos: Vector2, chunk_size: float, rng: RandomNumberGenerator):
	print("Spawning ", tree_clumps.size(), " tree clumps in chunk ", chunk_pos)
	for clump in tree_clumps:
		for tree_i in range(trees_per_cluster):
			var distance_from_center = rng.randf_range(0, tree_cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var tree_x = clump.center.x + cos(angle) * distance_from_center
			var tree_z = clump.center.y + sin(angle) * distance_from_center
			
			var world_x = chunk_pos.x * chunk_size + tree_x
			var world_z = chunk_pos.y * chunk_size + tree_z
			var height = get_terrain_height_at(world_x, world_z)
			
			var scale_factor = rng.randf_range(tree_min_scale, tree_max_scale)
			
			# Create individual tree instance
			var tree_instance = MeshInstance3D.new()
			tree_instance.mesh = tree_mesh
			tree_instance.material_override = tree_material
			
			# Create collision for tree
			var collision_body = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			var cylinder_shape = CylinderShape3D.new()
			cylinder_shape.height = scale_factor * tree_aspect_ratio
			cylinder_shape.radius = tree_collision_radius
			collision_shape.shape = cylinder_shape
			
			collision_body.add_child(collision_shape)
			tree_instance.add_child(collision_body)
			
			# Set transform
			var transform = Transform3D()
			transform = transform.scaled(Vector3(scale_factor, scale_factor, scale_factor))
			transform = transform.rotated(Vector3.UP, deg_to_rad(rng.randf_range(0, 360)))
			transform.origin = Vector3(world_x, height - (scale_factor * tree_aspect_ratio * 0.1), world_z)
			
			tree_instance.transform = transform
			container.add_child(tree_instance)

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

func remove_chunk(chunk_key: String):
	if chunk_key in spawned_chunks:
		spawned_chunks[chunk_key].queue_free()
		spawned_chunks.erase(chunk_key)
