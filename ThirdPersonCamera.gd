extends Node3D

@export var target: Node3D
@export var distance: float = 5.0
@export var height_offset: float = 2.0
@export var follow_speed: float = 5.0
@export var rotation_speed: float = 3.0

var camera_angle_h: float = 0.0
var camera_angle_v: float = -20.0

@onready var camera: Camera3D = $Camera3D

func _ready():
	if not target:
		target = get_parent().find_child("Player")

func _input(event):
	if Input.is_action_pressed("camera_left"):
		camera_angle_h -= rotation_speed
	if Input.is_action_pressed("camera_right"):
		camera_angle_h += rotation_speed
	if Input.is_action_pressed("camera_up"):
		camera_angle_v = clamp(camera_angle_v + rotation_speed, -60, 60)
	if Input.is_action_pressed("camera_down"):
		camera_angle_v = clamp(camera_angle_v - rotation_speed, -60, 60)

func _process(delta):
	if not target:
		return
	
	var target_position = target.global_position
	var camera_pos = Vector3()
	
	camera_pos.x = target_position.x + distance * sin(deg_to_rad(camera_angle_h)) * cos(deg_to_rad(camera_angle_v))
	camera_pos.z = target_position.z + distance * cos(deg_to_rad(camera_angle_h)) * cos(deg_to_rad(camera_angle_v))
	camera_pos.y = target_position.y + height_offset + distance * sin(deg_to_rad(camera_angle_v))
	
	global_position = global_position.lerp(camera_pos, follow_speed * delta)
	look_at(target_position + Vector3.UP, Vector3.UP)