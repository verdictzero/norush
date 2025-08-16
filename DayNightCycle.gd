extends Node3D

@export var day_length: float = 600.0
@export var sun_color_day: Color = Color(1.0, 0.95, 0.8)
@export var sun_color_sunset: Color = Color(1.0, 0.6, 0.3)
@export var sun_color_night: Color = Color(0.1, 0.1, 0.3)
@export var ambient_day: Color = Color(0.4, 0.4, 0.4)
@export var ambient_night: Color = Color(0.05, 0.05, 0.1)
@export var fog_enabled: bool = true
@export var fog_density: float = 0.005
@export var fog_start: float = 50.0
@export var fog_end: float = 400.0

var time_of_day: float = 0.5
var sun_light: DirectionalLight3D
var environment: Environment
var skybox_day: Texture2D
var skybox_morning: Texture2D
var skybox_evening: Texture2D
var skybox_night: Texture2D

func _ready():
	sun_light = get_parent().find_child("DirectionalLight3D")
	setup_environment()
	load_skyboxes()

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

func load_skyboxes():
	# Load skyboxes with error handling
	if ResourceLoader.exists("res://day.exr"):
		skybox_day = load("res://day.exr")
	if ResourceLoader.exists("res://morning.exr"):
		skybox_morning = load("res://morning.exr")
	if ResourceLoader.exists("res://evening.exr"):
		skybox_evening = load("res://evening.exr")
	if ResourceLoader.exists("res://night.exr"):
		skybox_night = load("res://night.exr")

func _process(delta):
	time_of_day += delta / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	update_lighting()

func update_lighting():
	if not sun_light or not environment:
		return
	
	var sun_angle = (time_of_day - 0.25) * 2 * PI
	var sun_height = sin(sun_angle)
	var sun_rotation = -sun_angle + PI/2
	
	sun_light.rotation_degrees.x = rad_to_deg(sun_rotation)
	
	var light_intensity = clamp(sun_height + 0.2, 0.1, 1.0)
	sun_light.light_energy = light_intensity
	
	var sun_color: Color
	if sun_height > 0.8:
		sun_color = sun_color_day
	elif sun_height > 0.1:
		var t = (sun_height - 0.1) / 0.7
		sun_color = sun_color_sunset.lerp(sun_color_day, t)
	elif sun_height > -0.1:
		var t = (sun_height + 0.1) / 0.2
		sun_color = sun_color_night.lerp(sun_color_sunset, t)
	else:
		sun_color = sun_color_night
	
	sun_light.light_color = sun_color
	
	# Update ambient lighting
	var ambient_color = ambient_night.lerp(ambient_day, clamp(sun_height + 0.3, 0, 1))
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = clamp(light_intensity * 0.3, 0.05, 0.3)
	
	# Update skybox based on time of day
	update_skybox()
	
	# Update fog color based on time of day
	if fog_enabled and environment.fog_enabled:
		update_fog_color()

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
