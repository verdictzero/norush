extends Node3D

# Preload flesh cube prefab
@export var flesh_cube_scene: PackedScene = preload("res://FleshCube.tscn")

var death_sites: Array[Vector3] = []
var max_death_sites: int = 10

# Performance tracking
var active_debris: Array[Node] = []
var max_active_debris: int = 50

func create_explosion(position: Vector3):
	print("Creating explosion at: ", position)
	death_sites.append(position)
	if death_sites.size() > max_death_sites:
		death_sites.pop_front()
	
	# Clean up old debris if we have too many
	cleanup_old_debris()
	
	create_cube_gore(position)
	create_fluid_splatter(position)

func create_cube_gore(explosion_pos: Vector3):
	var debris_count = 8  # Reduced from 15 to improve performance
	
	for i in range(debris_count):
		if not flesh_cube_scene:
			print("FleshCube scene not loaded, skipping gore creation")
			return
		
		# Instance the flesh cube prefab
		var debris = flesh_cube_scene.instantiate()
		
		# Set random position around explosion
		debris.position = explosion_pos + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.5, 2.5),  # Start higher to prevent immediate terrain collision
			randf_range(-1.0, 1.0)
		)
		
		# Add random scale variation
		var scale_factor = randf_range(0.7, 1.5)
		debris.scale = Vector3.ONE * scale_factor
		
		# Apply stronger physics forces for faster movement
		var force = Vector3(
			randf_range(-40, 40),
			randf_range(25, 60),  # Stronger upward force
			randf_range(-40, 40)
		)
		
		# Ensure we have a valid scene tree before adding
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(debris)
			active_debris.append(debris)
			
			# Connect cleanup signal
			if debris.has_signal("tree_exiting"):
				debris.tree_exiting.connect(_on_debris_removed.bind(debris))
			
			# Wait one frame for physics to initialize, then apply forces
			await get_tree().process_frame
			if is_instance_valid(debris):
				debris.apply_impulse(force)
				debris.angular_velocity = Vector3(
					randf_range(-15, 15),
					randf_range(-15, 15),
					randf_range(-15, 15)
				)
		else:
			debris.queue_free()

func create_fluid_splatter(explosion_pos: Vector3):
	for i in range(8):
		var splatter = create_splatter_decal(explosion_pos, i)
		get_tree().current_scene.add_child(splatter)
		create_fade_timer(splatter)
	
	create_particle_blood(explosion_pos)

func create_splatter_decal(center_pos: Vector3, index: int) -> Decal:
	var decal = Decal.new()
	
	var blood_texture = load("res://blood.tga")
	
	decal.texture_albedo = blood_texture
	decal.modulate = Color(randf_range(0.8, 1.2), randf_range(0.1, 0.3), randf_range(0.05, 0.15), randf_range(0.7, 1.0))
	
	var offset = Vector3(
		randf_range(-3, 3),
		randf_range(-0.5, 2),
		randf_range(-3, 3)
	)
	
	decal.position = center_pos + offset
	decal.rotation_degrees = Vector3(randf_range(-15, 15), randf_range(0, 360), randf_range(-15, 15))
	decal.size = Vector3(randf_range(1, 3), randf_range(1, 3), randf_range(1, 3))
	
	return decal

func create_particle_blood(explosion_pos: Vector3):
	for i in range(8):
		var blood_drop = RigidBody3D.new()
		var mesh_instance = MeshInstance3D.new()
		var collision_shape = CollisionShape3D.new()
		
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = randf_range(0.02, 0.08)
		sphere_mesh.height = sphere_mesh.radius * 2
		
		mesh_instance.mesh = sphere_mesh
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(randf_range(0.7, 1.0), randf_range(0.0, 0.1), randf_range(0.0, 0.05))
		material.metallic = 0.1
		material.roughness = 0.9
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh_instance.material_override = material
		
		var shape = SphereShape3D.new()
		shape.radius = sphere_mesh.radius
		collision_shape.shape = shape
		
		blood_drop.add_child(mesh_instance)
		blood_drop.add_child(collision_shape)
		
		blood_drop.position = explosion_pos + Vector3(
			randf_range(-0.3, 0.3),
			randf_range(0.5, 1.5),
			randf_range(-0.3, 0.3)
		)
		
		var force = Vector3(
			randf_range(-8, 8),
			randf_range(5, 15),
			randf_range(-8, 8)
		)
		
		get_tree().current_scene.add_child(blood_drop)
		blood_drop.apply_impulse(force)
		blood_drop.angular_velocity = Vector3(
			randf_range(-15, 15),
			randf_range(-15, 15),
			randf_range(-15, 15)
		)
		
		create_fade_timer(blood_drop)

func create_fade_timer(object: Node3D):
	var tween = create_tween()
	tween.tween_interval(25.0)
	tween.tween_method(fade_object.bind(object), 1.0, 0.0, 5.0)
	tween.tween_callback(func(): object.queue_free())

func fade_object(object: Node3D, alpha: float):
	if object and is_instance_valid(object):
		if object is RigidBody3D:
			var mesh_instance = object.get_child(0) as MeshInstance3D
			if mesh_instance and mesh_instance.material_override:
				mesh_instance.material_override.albedo_color.a = alpha
		elif object is Decal:
			object.modulate.a = alpha

func cleanup_old_debris():
	# Remove excess debris to maintain performance
	while active_debris.size() > max_active_debris:
		var oldest_debris = active_debris[0]
		if is_instance_valid(oldest_debris):
			oldest_debris.queue_free()
		active_debris.pop_front()
	
	# Clean up invalid references
	active_debris = active_debris.filter(func(debris): return is_instance_valid(debris))

func _on_debris_removed(debris: Node):
	var index = active_debris.find(debris)
	if index != -1:
		active_debris.remove_at(index)
