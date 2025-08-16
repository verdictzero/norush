extends Control

@onready var speedometer: ProgressBar = $UIBackground/VBoxContainer/SpeedometerContainer/Speedometer
@onready var speed_label: Label = $UIBackground/VBoxContainer/SpeedometerContainer/SpeedLabel
@onready var health_bar: ProgressBar = $UIBackground/VBoxContainer/HealthContainer/HealthBar
@onready var health_label: Label = $UIBackground/VBoxContainer/HealthContainer/HealthLabel
@onready var stress_bar: ProgressBar = $UIBackground/VBoxContainer/StressContainer/StressBar
@onready var stress_label: Label = $UIBackground/VBoxContainer/StressContainer/StressLabel
@onready var lives_label: Label = $UIBackground/VBoxContainer/LivesContainer/LivesLabel
@onready var time_label: Label = $UIBackground/VBoxContainer/TimeLabel
@onready var distance_label: Label = $UIBackground/VBoxContainer/DistanceLabel
@onready var score_label: Label = $UIBackground/VBoxContainer/ScoreLabel
@onready var fps_label: Label = $UIBackground/VBoxContainer/FPSLabel

var player: CharacterBody3D
var day_night_cycle: Node3D

func _ready():
	player = get_node("../Player")
	day_night_cycle = get_node("../DayNightCycle")
	
	speedometer.min_value = 0
	speedometer.max_value = player.max_speed
	
	health_bar.min_value = 0
	health_bar.max_value = 100
	
	stress_bar.min_value = 0
	stress_bar.max_value = 10

func _process(_delta):
	if player:
		update_speedometer()
		update_health()
		update_stress()
		update_lives()
		update_distance()
		update_score()
	if day_night_cycle:
		update_time()
	update_fps()

func update_speedometer():
	var speed = player.current_speed
	speedometer.value = speed
	speed_label.text = "Speed: %.1f" % speed
	
	if speed > player.max_speed * 0.7:
		speedometer.modulate = Color.RED
	elif speed > player.max_speed * 0.4:
		speedometer.modulate = Color.YELLOW
	else:
		speedometer.modulate = Color.GREEN

func update_health():
	health_bar.value = player.health
	health_label.text = "Health: %d/100" % player.health
	
	if player.health < 30:
		health_bar.modulate = Color.RED
	elif player.health < 60:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.GREEN

func update_stress():
	stress_bar.value = player.stress_level
	stress_label.text = "Stress: %.1f/10" % player.stress_level
	
	if player.stress_level > 7:
		stress_bar.modulate = Color.RED
	elif player.stress_level > 4:
		stress_bar.modulate = Color.YELLOW
	else:
		stress_bar.modulate = Color.GREEN

func update_lives():
	lives_label.text = "Lives: %d/10" % player.lives
	
	if player.lives <= 2:
		lives_label.modulate = Color.RED
	elif player.lives <= 5:
		lives_label.modulate = Color.YELLOW
	else:
		lives_label.modulate = Color.GREEN

func update_fps():
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	if fps < 30:
		fps_label.modulate = Color.RED
	elif fps < 60:
		fps_label.modulate = Color.YELLOW
	else:
		fps_label.modulate = Color.GREEN

func update_time():
	var time_str = day_night_cycle.get_time_string()
	var period = day_night_cycle.get_time_period()
	time_label.text = "%s (%s)" % [time_str, period]

func update_distance():
	var distance = player.distance_travelled
	if distance < 1000:
		distance_label.text = "Distance: %.1f m" % distance
	else:
		distance_label.text = "Distance: %.2f km" % (distance / 1000.0)

func update_score():
	score_label.text = "Score: %.1f pts" % player.current_score