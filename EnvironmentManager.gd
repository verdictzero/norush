extends Node3D

# Environment presets for different zones/conditions
enum EnvironmentPreset {
	CLEAR,
	LIGHT_FOG,
	HEAVY_FOG,
	STORMY,
	UNDERGROUND,
	TOXIC,
	ARCTIC,
	DESERT
}

# Fog settings
@export_group("Fog Controls")
@export var fog_enabled: bool = true
@export var fog_density: float = 0.01
@export var fog_color: Color = Color(0.8, 0.8, 0.9, 1.0)
@export var fog_sun_color: Color = Color(1.0, 0.9, 0.7, 1.0)
@export var fog_sun_amount: float = 0.5

# Skybox settings
@export_group("Skybox Controls")
@export var current_skybox: Environment
@export var skybox_rotation_speed: float = 0.1
@export var skybox_energy: float = 1.0

# Transition settings
@export_group("Transition Controls")
@export var transition_duration: float = 2.0
@export var auto_transition: bool = true

# Zone-based triggers
@export_group("Zone Triggers")
@export var use_distance_zones: bool = true
@export var zone_check_interval: float = 1.0

# Environment presets data
var environment_presets = {
	EnvironmentPreset.CLEAR: {
		"fog_enabled": false,
		"fog_density": 0.0,
		"fog_color": Color(0.8, 0.8, 0.9, 1.0),
		"skybox_energy": 1.0,
		"name": "Clear"
	},
	EnvironmentPreset.LIGHT_FOG: {
		"fog_enabled": true,
		"fog_density": 0.005,
		"fog_color": Color(0.9, 0.9, 0.95, 1.0),
		"skybox_energy": 0.8,
		"name": "Light Fog"
	},
	EnvironmentPreset.HEAVY_FOG: {
		"fog_enabled": true,
		"fog_density": 0.02,
		"fog_color": Color(0.7, 0.7, 0.8, 1.0),
		"skybox_energy": 0.4,
		"name": "Heavy Fog"
	},
	EnvironmentPreset.STORMY: {
		"fog_enabled": true,
		"fog_density": 0.015,
		"fog_color": Color(0.4, 0.4, 0.5, 1.0),
		"skybox_energy": 0.3,
		"name": "Stormy"
	},
	EnvironmentPreset.UNDERGROUND: {
		"fog_enabled": true,
		"fog_density": 0.01,
		"fog_color": Color(0.3, 0.3, 0.4, 1.0),
		"skybox_energy": 0.1,
		"name": "Underground"
	},
	EnvironmentPreset.TOXIC: {
		"fog_enabled": true,
		"fog_density": 0.03,
		"fog_color": Color(0.6, 0.8, 0.3, 1.0),
		"skybox_energy": 0.5,
		"name": "Toxic"
	},
	EnvironmentPreset.ARCTIC: {
		"fog_enabled": true,
		"fog_density": 0.008,
		"fog_color": Color(0.9, 0.95, 1.0, 1.0),
		"skybox_energy": 1.2,
		"name": "Arctic"
	},
	EnvironmentPreset.DESERT: {
		"fog_enabled": true,
		"fog_density": 0.003,
		"fog_color": Color(1.0, 0.9, 0.7, 1.0),
		"skybox_energy": 1.5,
		"name": "Desert"
	}
}

# Zone definitions (distance-based)
var distance_zones = [
	{"min_distance": 0, "max_distance": 500, "preset": EnvironmentPreset.CLEAR},
	{"min_distance": 500, "max_distance": 1000, "preset": EnvironmentPreset.LIGHT_FOG},
	{"min_distance": 1000, "max_distance": 2000, "preset": EnvironmentPreset.HEAVY_FOG},
	{"min_distance": 2000, "max_distance": 5000, "preset": EnvironmentPreset.STORMY},
	{"min_distance": 5000, "max_distance": 999999, "preset": EnvironmentPreset.TOXIC}
]

# Runtime variables
var current_preset: EnvironmentPreset = EnvironmentPreset.CLEAR
var target_preset: EnvironmentPreset = EnvironmentPreset.CLEAR
var transition_tween: Tween
var player: Node3D
var zone_check_timer: float = 0.0

# Environment state for transitions
var current_fog_density: float = 0.0
var current_fog_color: Color = Color.WHITE
var current_skybox_energy: float = 1.0
var target_fog_density: float = 0.0
var target_fog_color: Color = Color.WHITE
var target_skybox_energy: float = 1.0

func _ready():
	# Find player reference
	player = get_node_or_null("../Player")
	if not player:
		print("EnvironmentManager: Player not found, distance-based zones disabled")
		use_distance_zones = false
	
	# Get or create environment
	setup_environment()
	
	# Apply initial preset
	apply_preset(current_preset, false)

func _process(delta):
	# Handle skybox rotation
	if current_skybox and skybox_rotation_speed != 0.0:
		current_skybox.sky.sky_rotation += Vector3(0, skybox_rotation_speed * delta, 0)
	
	# Check distance-based zones
	if use_distance_zones and player:
		zone_check_timer += delta
		if zone_check_timer >= zone_check_interval:
			zone_check_timer = 0.0
			check_distance_zones()

func setup_environment():
	# Get the current environment or create one
	var viewport = get_viewport()
	if viewport.environment == null:
		current_skybox = Environment.new()
		viewport.environment = current_skybox
	else:
		current_skybox = viewport.environment
	
	# Ensure we have a sky
	if current_skybox.sky == null:
		current_skybox.sky = Sky.new()
		current_skybox.sky.sky_material = ProceduralSkyMaterial.new()
	
	# Set up fog if not already configured
	current_skybox.fog_enabled = fog_enabled

func apply_preset(preset: EnvironmentPreset, animate: bool = true):
	if not environment_presets.has(preset):
		print("EnvironmentManager: Unknown preset: ", preset)
		return
	
	var preset_data = environment_presets[preset]
	target_preset = preset
	
	# Set target values
	target_fog_density = preset_data.fog_density
	target_fog_color = preset_data.fog_color
	target_skybox_energy = preset_data.skybox_energy
	
	if animate and transition_duration > 0.0:
		start_transition()
	else:
		# Apply immediately
		apply_environment_settings(preset_data)
		current_preset = preset

func start_transition():
	# Stop any existing transition
	if transition_tween:
		transition_tween.kill()
	
	# Store current values
	current_fog_density = current_skybox.fog_density if current_skybox.fog_enabled else 0.0
	current_fog_color = current_skybox.fog_light_color
	current_skybox_energy = current_skybox.sky_energy_multiplier
	
	# Create new tween
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# Animate fog density
	transition_tween.tween_method(set_fog_density, current_fog_density, target_fog_density, transition_duration)
	
	# Animate fog color
	transition_tween.tween_method(set_fog_color, current_fog_color, target_fog_color, transition_duration)
	
	# Animate skybox energy
	transition_tween.tween_method(_set_skybox_energy_internal, current_skybox_energy, target_skybox_energy, transition_duration)
	
	# Update current preset when done
	transition_tween.tween_callback(func(): current_preset = target_preset).set_delay(transition_duration)

func apply_environment_settings(preset_data: Dictionary):
	if not current_skybox:
		return
	
	# Apply fog settings
	current_skybox.fog_enabled = preset_data.fog_enabled
	current_skybox.fog_density = preset_data.fog_density
	current_skybox.fog_light_color = preset_data.fog_color
	current_skybox.fog_light_energy = fog_sun_amount
	current_skybox.fog_sun_scatter = fog_sun_amount
	
	# Apply skybox settings
	current_skybox.sky_energy_multiplier = preset_data.skybox_energy
	
	print("EnvironmentManager: Applied preset - ", preset_data.name)

func set_fog_density(value: float):
	if current_skybox:
		current_skybox.fog_density = value
		current_skybox.fog_enabled = value > 0.0

func set_fog_color(color: Color):
	if current_skybox:
		current_skybox.fog_light_color = color

func _set_skybox_energy_internal(value: float):
	if current_skybox:
		current_skybox.sky_energy_multiplier = value

func check_distance_zones():
	if not player:
		return
	
	var distance = player.distance_travelled if player.has_method("get") and "distance_travelled" in player else 0.0
	
	for zone in distance_zones:
		if distance >= zone.min_distance and distance < zone.max_distance:
			if zone.preset != current_preset and zone.preset != target_preset:
				apply_preset(zone.preset, auto_transition)
			break

# Public API functions
func set_preset(preset: EnvironmentPreset, animate: bool = true):
	apply_preset(preset, animate)

func set_custom_fog(density: float, color: Color, animate: bool = true):
	target_fog_density = density
	target_fog_color = color
	
	if animate and transition_duration > 0.0:
		if transition_tween:
			transition_tween.kill()
		
		current_fog_density = current_skybox.fog_density if current_skybox.fog_enabled else 0.0
		current_fog_color = current_skybox.fog_light_color
		
		transition_tween = create_tween()
		transition_tween.set_parallel(true)
		transition_tween.tween_method(set_fog_density, current_fog_density, target_fog_density, transition_duration)
		transition_tween.tween_method(set_fog_color, current_fog_color, target_fog_color, transition_duration)
	else:
		set_fog_density(density)
		set_fog_color(color)

func set_skybox_energy(energy: float, animate: bool = true):
	target_skybox_energy = energy
	
	if animate and transition_duration > 0.0:
		if transition_tween:
			transition_tween.kill()
		
		current_skybox_energy = current_skybox.sky_energy_multiplier
		transition_tween = create_tween()
		transition_tween.tween_method(_set_skybox_energy_internal, current_skybox_energy, target_skybox_energy, transition_duration)
	else:
		_set_skybox_energy_internal(energy)

func add_custom_zone(min_dist: float, max_dist: float, preset: EnvironmentPreset):
	distance_zones.append({
		"min_distance": min_dist,
		"max_distance": max_dist,
		"preset": preset
	})
	# Sort zones by min_distance
	distance_zones.sort_custom(func(a, b): return a.min_distance < b.min_distance)

func get_current_preset_name() -> String:
	if environment_presets.has(current_preset):
		return environment_presets[current_preset].name
	return "Unknown"

# Debug functions
func list_presets():
	print("Available Environment Presets:")
	for preset in environment_presets:
		var data = environment_presets[preset]
		print("  ", preset, ": ", data.name)

func print_current_state():
	print("EnvironmentManager State:")
	print("  Current Preset: ", get_current_preset_name())
	print("  Fog Enabled: ", current_skybox.fog_enabled if current_skybox else "No skybox")
	print("  Fog Density: ", current_skybox.fog_density if current_skybox else "No skybox")
	print("  Skybox Energy: ", current_skybox.sky_energy_multiplier if current_skybox else "No skybox")
	if player:
		print("  Player Distance: ", player.distance_travelled if "distance_travelled" in player else "Unknown")