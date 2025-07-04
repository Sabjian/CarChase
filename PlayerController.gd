extends CharacterBody2D

@export var max_speed: float = 300.0
@export var acceleration: float = 600.0
@export var deceleration: float = 400.0
@export var turn_speed: float = 4.0
@export var min_turn_speed: float = 5.0
@export var stationary_turn_speed: float = 2.0

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
	
	# Handle turning - improved low-speed turning
	if turn_input != 0:
		var effective_turn_speed: float
		
		if abs(current_speed) < min_turn_speed:
			# Allow stationary turning
			effective_turn_speed = stationary_turn_speed
		else:
			# Speed-dependent turning with improved curve
			var speed_factor = min(abs(current_speed) / max_speed, 1.0)
			# Use a more gradual curve that allows good turning at lower speeds
			var turn_curve = 0.3 + (speed_factor * 0.7)  # Range from 0.3 to 1.0
			effective_turn_speed = turn_speed * turn_curve
		
		rotation += turn_input * effective_turn_speed * delta
	
	# Apply movement
	var forward = Vector2.UP.rotated(rotation)
	velocity = forward * current_speed
