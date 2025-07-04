extends CharacterBody2D

@export var max_speed: float = 300.0
@export var acceleration: float = 600.0
@export var deceleration: float = 400.0
@export var turn_speed: float = 2.0

var current_speed: float = 0.0

func _ready():
	pass

func _physics_process(delta):
	var old_pos = global_position
	handle_input(delta)
	move_and_slide()
	
func handle_input(delta):
	var input_dir = Vector2.ZERO
	var turn_input = 0.0
	
	# Get input
	if Input.is_action_pressed("ui_up"):
		input_dir.y = -1
	elif Input.is_action_pressed("ui_down"):
		input_dir.y = 1
	
	if Input.is_action_pressed("ui_left"):
		turn_input = -1
	elif Input.is_action_pressed("ui_right"):
		turn_input = 1
	
	# Handle acceleration/deceleration
	if input_dir.y != 0:
		if input_dir.y < 0:  # Forward
			current_speed = move_toward(current_speed, max_speed, acceleration * delta)
		else:  # Backward
			current_speed = move_toward(current_speed, -max_speed * 0.5, acceleration * delta)
	else:
		# Decelerate when no input
		current_speed = move_toward(current_speed, 0, deceleration * delta)
	
	# Handle turning - only when moving
	if abs(current_speed) > 20:
		rotation += turn_input * turn_speed * delta * (abs(current_speed) / max_speed)
	
	# Apply movement
	var forward = Vector2.UP.rotated(rotation)
	velocity = forward * current_speed
