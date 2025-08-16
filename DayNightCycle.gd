extends Node3D

# Day/Night cycle settings
@export var day_length: float = 600.0
@export var transition_duration: float = 30.0  # How long transitions take in seconds

# Skybox settings
@export_group("Skyboxes")
@export var skybox_morning: Texture2D
@export var skybox_day: Texture2D  
@export var skybox_evening: Texture2D
@export var skybox_night: Texture2D

# Sun lighting settings
@export_group("Sun Lighting")
@export var sun_color_morning: Color = Color(1.0, 0.8, 0.6)
@export var sun_color_day: Color = Color(1.0, 0.95, 0.8)
@export var sun_color_evening: Color = Color(1.0, 0.6, 0.3)
@export var sun_color_night: Color = Color(0.1, 0.1, 0.3)

# Ambient lighting settings
@export_group("Ambient Lighting") 
@export var ambient_morning: Color = Color(0.3, 0.3, 0.4)
@export var ambient_day: Color = Color(0.4, 0.4, 0.4)
@export var ambient_evening: Color = Color(0.5, 0.3, 0.2)
@export var ambient_night: Color = Color(0.05, 0.05, 0.1)

# Fog settings
@export_group("Fog Settings")
@export var fog_enabled: bool = true
@export var fog_density: float = 0.001
@export var fog_morning_color: Color = Color(1.0, 0.8, 0.6, 1.0)
@export var fog_day_color: Color = Color(0.8, 0.9, 1.0, 1.0)
@export var fog_evening_color: Color = Color(1.0, 0.7, 0.5, 1.0)
@export var fog_night_color: Color = Color(0.3, 0.4, 0.6, 1.0)

var time_of_day: float = 0.5
var sun_light: DirectionalLight3D
var environment: Environment

# Smooth transition system
var current_skybox: Texture2D
var target_skybox: Texture2D
var transition_tween: Tween
var is_transitioning: bool = false

func _ready():
	sun_light = get_parent().find_child("DirectionalLight3D")
	setup_environment()
	setup_transition_system()
	# Auto-load skyboxes if not set in inspector
	auto_load_skyboxes()

func setup_environment():
	# Try to get existing environment first
	var camera = get_viewport().get_camera_3d()
	if camera and camera.environment:
		environment = camera.environment
	else:
		environment = Environment.new()
		if camera:
			camera.environment = environment
	
	# Set up fog
	if fog_enabled:
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.8, 0.9, 1.0)
		environment.fog_light_energy = 1.0
		environment.fog_sun_scatter = 0.1
		environment.fog_density = fog_density
		environment.fog_aerial_perspective = 0.1
		environment.fog_height = 0.0
		environment.fog_height_density = 0.0
	
	# Set up sky only if we don't have one
	if not environment.sky:
		environment.background_mode = Environment.BG_SKY
		environment.sky = Sky.new()
		environment.sky.sky_material = PanoramaSkyMaterial.new()

func setup_transition_system():
	transition_tween = create_tween()
	transition_tween.stop()

func auto_load_skyboxes():
	# Auto-load skyboxes only if not set in inspector
	if not skybox_day and ResourceLoader.exists("res://day.exr"):
		skybox_day = load("res://day.exr")
	if not skybox_morning and ResourceLoader.exists("res://morning.exr"):
		skybox_morning = load("res://morning.exr")
	if not skybox_evening and ResourceLoader.exists("res://evening.exr"):
		skybox_evening = load("res://evening.exr")
	if not skybox_night and ResourceLoader.exists("res://night.exr"):
		skybox_night = load("res://night.exr")
	
	# Set initial skybox
	current_skybox = get_skybox_for_time(time_of_day)

func _process(delta):
	time_of_day += delta / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	update_lighting()

func update_lighting():
	if not sun_light or not environment:
		return
	
	# Update sun position
	var sun_angle = (time_of_day - 0.25) * 2 * PI
	var sun_height = sin(sun_angle)
	var sun_rotation = -sun_angle + PI/2
	sun_light.rotation_degrees.x = rad_to_deg(sun_rotation)
	
	# Update sun intensity
	var light_intensity = clamp(sun_height + 0.2, 0.1, 1.0)
	sun_light.light_energy = light_intensity
	
	# Smooth sun color transitions
	var sun_color = get_interpolated_sun_color()
	sun_light.light_color = sun_color
	
	# Smooth ambient lighting transitions
	var ambient_color = get_interpolated_ambient_color()
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = clamp(light_intensity * 0.3, 0.05, 0.3)
	
	# Update skybox with smooth transitions
	update_skybox_smooth()
	
	# Update fog with smooth transitions
	if fog_enabled and environment.fog_enabled:
		update_fog_smooth()

func update_skybox():
	if not environment or not environment.sky or not environment.sky.sky_material:
		return
	
	var sky_material = environment.sky.sky_material as PanoramaSkyMaterial
	if not sky_material:
		return
	
	var hour = time_of_day * 24
	var current_skybox: Texture2D
	
	# Determine which skybox to use based on time
	if hour >= 6 && hour < 12:
		# Morning transition
		if hour < 8:
			var t = (hour - 6) / 2.0
			current_skybox = skybox_morning if skybox_morning else skybox_day
		else:
			current_skybox = skybox_day if skybox_day else skybox_morning
	elif hour >= 12 && hour < 18:
		# Day
		current_skybox = skybox_day if skybox_day else skybox_morning
	elif hour >= 18 && hour < 22:
		# Evening
		current_skybox = skybox_evening if skybox_evening else skybox_day
	else:
		# Night
		current_skybox = skybox_night if skybox_night else skybox_evening
	
	if current_skybox:
		sky_material.panorama = current_skybox

func update_fog_color():
	if not environment:
		return
	
	var hour = time_of_day * 24
	var fog_color: Color
	
	# Set fog color based on time of day to match skybox periods
	if hour >= 6 && hour < 12:
		# Morning - warm golden/orange tones
		if hour < 8:
			fog_color = Color(1.0, 0.8, 0.6, 1.0)  # Warm morning
		else:
			fog_color = Color(0.9, 0.9, 1.0, 1.0)  # Clear morning
	elif hour >= 12 && hour < 18:
		# Day - clear blue
		fog_color = Color(0.8, 0.9, 1.0, 1.0)
	elif hour >= 18 && hour < 22:
		# Evening - warm orange/red
		fog_color = Color(1.0, 0.7, 0.5, 1.0)
	else:
		# Night - cool blue/purple
		fog_color = Color(0.3, 0.4, 0.6, 1.0)
	
	environment.fog_light_color = fog_color

func get_time_string() -> String:
	var hours = int(time_of_day * 24)
	var minutes = int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

func get_time_period() -> String:
	var hour = time_of_day * 24
	if hour >= 6 && hour < 12:
		return "Morning"
	elif hour >= 12 && hour < 18:
		return "Afternoon" 
	elif hour >= 18 && hour < 22:
		return "Evening"
	else:
		return "Night"

func get_current_time_normalized() -> float:
	return time_of_day

func get_interpolated_sun_color() -> Color:
	var hour = time_of_day * 24
	
	if hour >= 5 && hour < 8:  # Dawn
		var t = (hour - 5) / 3.0
		return sun_color_night.lerp(sun_color_morning, t)
	elif hour >= 8 && hour < 11:  # Morning to Day
		var t = (hour - 8) / 3.0
		return sun_color_morning.lerp(sun_color_day, t)
	elif hour >= 11 && hour < 17:  # Day
		return sun_color_day
	elif hour >= 17 && hour < 20:  # Day to Evening
		var t = (hour - 17) / 3.0
		return sun_color_day.lerp(sun_color_evening, t)
	elif hour >= 20 && hour < 23:  # Evening to Night
		var t = (hour - 20) / 3.0
		return sun_color_evening.lerp(sun_color_night, t)
	else:  # Night
		return sun_color_night

func get_interpolated_ambient_color() -> Color:
	var hour = time_of_day * 24
	
	if hour >= 5 && hour < 8:  # Dawn
		var t = (hour - 5) / 3.0
		return ambient_night.lerp(ambient_morning, t)
	elif hour >= 8 && hour < 11:  # Morning to Day
		var t = (hour - 8) / 3.0
		return ambient_morning.lerp(ambient_day, t)
	elif hour >= 11 && hour < 17:  # Day
		return ambient_day
	elif hour >= 17 && hour < 20:  # Day to Evening
		var t = (hour - 17) / 3.0
		return ambient_day.lerp(ambient_evening, t)
	elif hour >= 20 && hour < 23:  # Evening to Night
		var t = (hour - 20) / 3.0
		return ambient_evening.lerp(ambient_night, t)
	else:  # Night
		return ambient_night

func get_skybox_for_time(time: float) -> Texture2D:
	var hour = time * 24
	
	if hour >= 6 && hour < 12:
		return skybox_morning if skybox_morning else skybox_day
	elif hour >= 12 && hour < 18:
		return skybox_day if skybox_day else skybox_morning
	elif hour >= 18 && hour < 22:
		return skybox_evening if skybox_evening else skybox_day
	else:
		return skybox_night if skybox_night else skybox_evening

func update_skybox_smooth():
	if not environment or not environment.sky or not environment.sky.sky_material:
		return
	
	var sky_material = environment.sky.sky_material as PanoramaSkyMaterial
	if not sky_material:
		return
	
	var new_target = get_skybox_for_time(time_of_day)
	
	# Check if we need to transition to a new skybox
	if new_target != target_skybox and new_target != null:
		target_skybox = new_target
		
		# Only start transition if we're not already transitioning to this skybox
		if not is_transitioning:
			start_skybox_transition()

func start_skybox_transition():
	if not target_skybox or target_skybox == current_skybox:
		return
	
	is_transitioning = true
	
	# Stop any existing tween
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	
	# Smoothly transition skybox
	var sky_material = environment.sky.sky_material as PanoramaSkyMaterial
	sky_material.panorama = target_skybox
	
	# Mark transition as complete
	transition_tween.tween_callback(func(): 
		current_skybox = target_skybox
		is_transitioning = false
	).set_delay(transition_duration / day_length)

func update_fog_smooth():
	if not environment:
		return
	
	var hour = time_of_day * 24
	var fog_color: Color
	
	if hour >= 5 && hour < 8:  # Dawn
		var t = (hour - 5) / 3.0
		fog_color = fog_night_color.lerp(fog_morning_color, t)
	elif hour >= 8 && hour < 11:  # Morning to Day
		var t = (hour - 8) / 3.0
		fog_color = fog_morning_color.lerp(fog_day_color, t)
	elif hour >= 11 && hour < 17:  # Day
		fog_color = fog_day_color
	elif hour >= 17 && hour < 20:  # Day to Evening
		var t = (hour - 17) / 3.0
		fog_color = fog_day_color.lerp(fog_evening_color, t)
	elif hour >= 20 && hour < 23:  # Evening to Night
		var t = (hour - 20) / 3.0
		fog_color = fog_evening_color.lerp(fog_night_color, t)
	else:  # Night
		fog_color = fog_night_color
	
	environment.fog_light_color = fog_color
