extends Control

# Robust F3 Debug Menu for No Rush game
# Allows tweaking game parameters in real-time

var is_visible: bool = false
var debug_panel: Panel
var scroll_container: ScrollContainer
var vbox_container: VBoxContainer

# References to game systems
var player: RigidBody3D
var terrain_manager: Node3D
var vegetation_spawner: Node3D
var mountain_renderer: Node3D
var position_manager: Node
var ui: Control

# Debug controls
var debug_controls: Dictionary = {}

func _ready():
	setup_debug_menu()
	find_game_systems()
	create_debug_controls()
	set_visible(false)

func setup_debug_menu():
	# Create the main debug panel
	debug_panel = Panel.new()
	debug_panel.size = Vector2(400, 600)
	debug_panel.position = Vector2(50, 50)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.CYAN
	debug_panel.add_theme_stylebox_override("panel", style)
	
	# Title label
	var title = Label.new()
	title.text = "F3 Debug Menu - No Rush"
	title.position = Vector2(10, 10)
	title.size = Vector2(380, 30)
	title.add_theme_color_override("font_color", Color.CYAN)
	debug_panel.add_child(title)
	
	# Scroll container for all controls
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(10, 40)
	scroll_container.size = Vector2(380, 550)
	debug_panel.add_child(scroll_container)
	
	# VBox for organizing controls
	vbox_container = VBoxContainer.new()
	vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(vbox_container)
	
	add_child(debug_panel)

func find_game_systems():
	var main = get_parent()
	player = main.find_child("Player")
	terrain_manager = main.find_child("TerrainManager")
	vegetation_spawner = main.find_child("VegetationSpawner")
	mountain_renderer = main.find_child("MountainRenderer")
	position_manager = main.find_child("PositionManager")
	ui = main.find_child("UI")

func create_debug_controls():
	# Player Physics Section
	add_section_header("Player Physics")
	
	if player:
		add_float_control("Torque Strength", player, "torque_strength", 0.1, 20.0, 0.1)
		add_float_control("Max Speed", player, "max_speed", 1.0, 50.0, 1.0)
		add_float_control("Max Angular Velocity", player, "max_angular_velocity", 1.0, 30.0, 1.0)
		add_float_control("Rolling Friction", player, "rolling_friction", 0.1, 1.0, 0.01)
		add_float_control("Stress Buildup Rate", player, "stress_buildup_rate", 0.1, 2.0, 0.05)
		add_float_control("Health Damage Rate", player, "health_damage_rate", 1.0, 20.0, 0.5)
		add_button_control("Reset Player Position", reset_player_position)
		add_button_control("Heal Player", heal_player)
	
	# Terrain Section
	add_section_header("Terrain")
	
	if terrain_manager:
		add_int_control("Render Distance", terrain_manager, "render_distance", 5, 50, 1)
		add_int_control("Chunk Size", terrain_manager, "chunk_size", 16, 128, 8)
		add_button_control("Refresh Terrain", refresh_terrain)
	
	# Vegetation Section
	add_section_header("Vegetation")
	
	if vegetation_spawner:
		add_int_control("Bush Clusters Per Chunk", vegetation_spawner, "bush_clusters_per_chunk", 0, 10, 1)
		add_int_control("Tree Clusters Per Chunk", vegetation_spawner, "tree_clusters_per_chunk", 0, 10, 1)
		add_float_control("Tree Min Scale", vegetation_spawner, "tree_min_scale", 1.0, 20.0, 0.5)
		add_float_control("Tree Max Scale", vegetation_spawner, "tree_max_scale", 1.0, 30.0, 0.5)
		add_button_control("Refresh Vegetation", refresh_vegetation)
	
	# Mountains Section
	add_section_header("Mountains")
	
	if mountain_renderer:
		add_float_control("Mountain Distance", mountain_renderer, "mountain_distance", 100.0, 1000.0, 50.0)
		add_float_control("Mountain Height", mountain_renderer, "mountain_height", 20.0, 200.0, 10.0)
		add_int_control("Mountain Segments", mountain_renderer, "mountain_segments", 16, 128, 8)
		add_button_control("Refresh Mountains", refresh_mountains)
	
	# Position Manager Section
	add_section_header("Position Manager")
	
	if position_manager:
		add_float_control("Shift Threshold", position_manager, "shift_threshold", 100.0, 5000.0, 100.0)
		add_float_control("Shift Amount", position_manager, "shift_amount", 50.0, 2000.0, 50.0)
		add_button_control("Force World Shift", force_world_shift)
	
	# System Controls
	add_section_header("System Controls")
	add_button_control("Restart Game", restart_game)
	add_button_control("Clear All Chunks", clear_all_chunks)
	add_button_control("Show Performance Info", toggle_performance_info)

func add_section_header(title: String):
	var header = Label.new()
	header.text = "=== " + title + " ==="
	header.add_theme_color_override("font_color", Color.YELLOW)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_container.add_child(header)
	
	# Add some spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox_container.add_child(spacer)

func add_float_control(label_text: String, target_object: Object, property: String, min_val: float, max_val: float, step: float):
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(150, 0)
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step
	spinbox.value = target_object.get(property)
	spinbox.custom_minimum_size = Vector2(100, 0)
	
	spinbox.value_changed.connect(func(value): target_object.set(property, value))
	
	container.add_child(spinbox)
	vbox_container.add_child(container)
	
	debug_controls[property] = spinbox

func add_int_control(label_text: String, target_object: Object, property: String, min_val: int, max_val: int, step: int):
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(150, 0)
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step
	spinbox.value = target_object.get(property)
	spinbox.custom_minimum_size = Vector2(100, 0)
	
	spinbox.value_changed.connect(func(value): target_object.set(property, int(value)))
	
	container.add_child(spinbox)
	vbox_container.add_child(container)
	
	debug_controls[property] = spinbox

func add_button_control(label_text: String, callback: Callable):
	var button = Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	vbox_container.add_child(button)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			toggle_debug_menu()

func toggle_debug_menu():
	is_visible = !is_visible
	set_visible(is_visible)
	
	if is_visible:
		print("Debug menu opened")
		# Update all control values when opening
		refresh_control_values()
	else:
		print("Debug menu closed")

func refresh_control_values():
	# Update all spinbox values to match current object properties
	for property in debug_controls:
		var control = debug_controls[property]
		if control and is_instance_valid(control):
			var target = get_target_for_property(property)
			if target:
				control.value = target.get(property)

func get_target_for_property(property: String) -> Object:
	# Map properties to their target objects
	var player_props = ["torque_strength", "max_speed", "max_angular_velocity", "rolling_friction", "stress_buildup_rate", "health_damage_rate"]
	var terrain_props = ["render_distance", "chunk_size"]
	var vegetation_props = ["bush_clusters_per_chunk", "tree_clusters_per_chunk", "tree_min_scale", "tree_max_scale"]
	var mountain_props = ["mountain_distance", "mountain_height", "mountain_segments"]
	var position_props = ["shift_threshold", "shift_amount"]
	
	if property in player_props:
		return player
	elif property in terrain_props:
		return terrain_manager
	elif property in vegetation_props:
		return vegetation_spawner
	elif property in mountain_props:
		return mountain_renderer
	elif property in position_props:
		return position_manager
	
	return null

# Button callback functions
func reset_player_position():
	if player:
		player.global_position = Vector3(0, 5, 0)
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
		print("Player position reset")

func heal_player():
	if player:
		player.health = 100.0
		player.stress_level = 0.0
		print("Player healed")

func refresh_terrain():
	if terrain_manager:
		# Clear existing chunks and force regeneration
		for chunk_key in terrain_manager.chunks.keys():
			terrain_manager.remove_chunk(chunk_key)
		print("Terrain refreshed")

func refresh_vegetation():
	if vegetation_spawner:
		# Clear existing vegetation and force regeneration
		for chunk_key in vegetation_spawner.spawned_chunks.keys():
			vegetation_spawner.remove_chunk(chunk_key)
		print("Vegetation refreshed")

func refresh_mountains():
	if mountain_renderer:
		# Recreate mountain layers
		for child in mountain_renderer.get_children():
			child.queue_free()
		mountain_renderer.mountain_meshes.clear()
		mountain_renderer.mountain_materials.clear()
		mountain_renderer.call_deferred("create_mountain_layers")
		print("Mountains refreshed")

func force_world_shift():
	if position_manager:
		position_manager.shift_world()
		print("Forced world shift")

func restart_game():
	if player and player.has_method("restart_game"):
		player.restart_game()
		print("Game restarted")

func clear_all_chunks():
	refresh_terrain()
	refresh_vegetation()
	print("All chunks cleared")

func toggle_performance_info():
	if ui:
		# Toggle FPS display or other performance info
		var fps_label = ui.find_child("FPSLabel")
		if fps_label:
			fps_label.visible = !fps_label.visible
			print("Performance info toggled")

func _process(delta):
	if is_visible:
		# Update real-time info if needed
		pass