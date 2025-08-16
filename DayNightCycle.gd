extends Node3D

@export var day_length: float = 600.0
@export var sun_color_day: Color = Color(1.0, 0.95, 0.8)
@export var sun_color_sunset: Color = Color(1.0, 0.6, 0.3)
@export var sun_color_night: Color = Color(0.1, 0.1, 0.3)
@export var ambient_day: Color = Color(0.4, 0.4, 0.4)
@export var ambient_night: Color = Color(0.05, 0.05, 0.1)

var time_of_day: float = 0.5
var sun_light: DirectionalLight3D

func _ready():
	sun_light = get_parent().find_child("DirectionalLight3D")

func _process(delta):
	time_of_day += delta / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	update_lighting()

func update_lighting():
	if not sun_light:
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
	
	var env = get_viewport().get_camera_3d().environment
	if env:
		var ambient_color = ambient_night.lerp(ambient_day, clamp(sun_height + 0.3, 0, 1))
		env.ambient_light_color = ambient_color
		env.ambient_light_energy = clamp(light_intensity * 0.3, 0.05, 0.3)

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