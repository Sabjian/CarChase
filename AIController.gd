class_name AIController
extends CharacterBody2D

enum AIState {
	IDLE,
	DETECTION,
	CHASE,
	SEARCH
}

@export var max_speed: float = 150.0
@export var acceleration: float = 400.0
@export var deceleration: float = 600.0
@export var turn_speed: float = 3.0
@export var detection_range: float = 150.0
@export var search_time: float = 5.0
@export var patrol_speed: float = 50.0

var current_state: AIState = AIState.IDLE
var target_player: CharacterBody2D
var last_known_position: Vector2
var search_timer: float = 0.0
var current_speed: float = 0.0
var target_direction: Vector2 = Vector2.ZERO

@onready var detection_area: Area2D = $DetectionArea
@onready var line_of_sight_ray: RayCast2D = $LineOfSightRay
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent

func _ready():
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	navigation_agent.navigation_finished.connect(_on_navigation_agent_navigation_finished)
	
	call_deferred("_setup_navigation")

func _setup_navigation():
	await get_tree().physics_frame
	navigation_agent.target_position = global_position

func _physics_process(delta):
	_update_state(delta)
	_handle_movement(delta)
	move_and_slide()

func _update_state(delta):
	match current_state:
		AIState.IDLE:
			_handle_idle_state()
		AIState.DETECTION:
			_handle_detection_state()
		AIState.CHASE:
			_handle_chase_state()
		AIState.SEARCH:
			_handle_search_state(delta)

func _handle_idle_state():
	target_direction = Vector2.ZERO
	current_speed = 0.0

func _handle_detection_state():
	if target_player and _has_line_of_sight_to_player():
		_transition_to_chase()
	else:
		_transition_to_idle()

func _handle_chase_state():
	if target_player:
		if _has_line_of_sight_to_player():
			last_known_position = target_player.global_position
			_set_navigation_target(target_player.global_position)
		else:
			_transition_to_search()
	else:
		_transition_to_idle()

func _handle_search_state(delta):
	search_timer -= delta
	if search_timer <= 0.0:
		_transition_to_idle()
	elif target_player and _has_line_of_sight_to_player():
		_transition_to_chase()

func _handle_movement(delta):
	var target_velocity: Vector2 = Vector2.ZERO
	
	if navigation_agent.is_navigation_finished():
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)
	else:
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var direction: Vector2 = (next_path_position - global_position).normalized()
		
		var desired_speed: float = max_speed
		if current_state == AIState.SEARCH:
			desired_speed = patrol_speed
		
		current_speed = move_toward(current_speed, desired_speed, acceleration * delta)
		target_velocity = direction * current_speed
		
		if target_velocity.length() > 0:
			var target_angle = target_velocity.angle() + PI/2
			rotation = rotate_toward(rotation, target_angle, turn_speed * delta)
	
	velocity = target_velocity

func _has_line_of_sight_to_player() -> bool:
	if not target_player:
		return false
	
	var player_position = target_player.global_position
	var direction_to_player = (player_position - global_position).normalized()
	
	line_of_sight_ray.target_position = direction_to_player * detection_range
	line_of_sight_ray.force_raycast_update()
	
	if line_of_sight_ray.is_colliding():
		var collider = line_of_sight_ray.get_collider()
		return collider == target_player
	
	return false

func _set_navigation_target(target_pos: Vector2):
	navigation_agent.target_position = target_pos

func _transition_to_idle():
	current_state = AIState.IDLE
	target_player = null

func _transition_to_detection():
	current_state = AIState.DETECTION

func _transition_to_chase():
	current_state = AIState.CHASE
	if target_player:
		last_known_position = target_player.global_position

func _transition_to_search():
	current_state = AIState.SEARCH
	search_timer = search_time
	_set_navigation_target(last_known_position)

func _on_detection_area_body_entered(body):
	if body.name == "Player":
		target_player = body
		_transition_to_detection()

func _on_detection_area_body_exited(body):
	if body == target_player:
		if current_state == AIState.CHASE:
			_transition_to_search()
		else:
			_transition_to_idle()

func _on_navigation_agent_navigation_finished():
	if current_state == AIState.SEARCH:
		_transition_to_idle()

func get_current_state_name() -> String:
	match current_state:
		AIState.IDLE:
			return "IDLE"
		AIState.DETECTION:
			return "DETECTION"
		AIState.CHASE:
			return "CHASE"
		AIState.SEARCH:
			return "SEARCH"
		_:
			return "UNKNOWN"