extends Node3D

var death_sites: Array[Vector3] = []
var max_death_sites: int = 10

func create_explosion(position: Vector3):
	print("Creating explosion at: ", position)
	death_sites.append(position)
	if death_sites.size() > max_death_sites:
		death_sites.pop_front()
	
	create_cube_gore(position)
	create_fluid_splatter(position)

func create_cube_gore(explosion_pos: Vector3):
	var debris_count = 15
	
	for i in range(debris_count):
		var debris = RigidBody3D.new()
		var mesh_instance = MeshInstance3D.new()
		var collision_shape = CollisionShape3D.new()
		
		var size = randf_range(0.05, 0.4)
		var mesh: Mesh
		var shape_type = randi() % 4
		
		match shape_type:
			0:
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(size, size * randf_range(0.5, 2.0), size)
				mesh = box_mesh
			1:
				var sphere_mesh = SphereMesh.new()
				sphere_mesh.radius = size * 0.5
				sphere_mesh.height = size
				mesh = sphere_mesh
			2:
				var cylinder_mesh = CylinderMesh.new()
				cylinder_mesh.top_radius = size * 0.3
				cylinder_mesh.bottom_radius = size * 0.3
				cylinder_mesh.height = size * 1.5
				mesh = cylinder_mesh
			3:
				var prism_mesh = PrismMesh.new()
				prism_mesh.left_to_right = size
				prism_mesh.size = Vector3(size, size, size)
				mesh = prism_mesh
		
		mesh_instance.mesh = mesh
		
		# Keep cubes untextured (no material override)
		
		var shape = mesh.create_convex_shape()
		collision_shape.shape = shape
		
		debris.add_child(mesh_instance)
		debris.add_child(collision_shape)
		
		debris.position = explosion_pos + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0, 2),
			randf_range(-1.0, 1.0)
		)
		
		var force = Vector3(
			randf_range(-25, 25),
			randf_range(15, 40),
			randf_range(-25, 25)
		)
		
		# Ensure we have a valid scene tree before adding
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(debris)
			# Apply impulse after adding to scene
			debris.apply_impulse(force)
			debris.angular_velocity = Vector3(
				randf_range(-10, 10),
				randf_range(-10, 10),
				randf_range(-10, 10)
			)
			
			create_fade_timer(debris)
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
