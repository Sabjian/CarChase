class_name AIController
extends CharacterBody2D

enum AIState {
	IDLE,
	PATROL,
	DETECTION,
	CHASE,
	SEARCH
}

@export var max_speed: float = 150.0
@export var acceleration: float = 400.0
@export var deceleration: float = 600.0
@export var turn_speed: float = 6.0
@export var min_turn_speed: float = 8.0
@export var stationary_turn_speed: float = 3.0
@export var detection_range: float = 150.0
@export var search_time: float = 5.0
@export var patrol_speed: float = 80.0
@export var idle_time: float = 2.0

var current_state: AIState = AIState.IDLE
var target_player: CharacterBody2D
var last_known_position: Vector2
var search_timer: float = 0.0
var idle_timer: float = 0.0
var current_speed: float = 0.0
var target_direction: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var road_positions: Array[Vector2] = []

@onready var detection_area: Area2D = $DetectionArea
@onready var line_of_sight_ray: RayCast2D = $LineOfSightRay
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent

func _ready():
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	navigation_agent.navigation_finished.connect(_on_navigation_agent_navigation_finished)
	
	call_deferred("_setup_navigation")
	call_deferred("_initialize_patrol")

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
			_handle_idle_state(delta)
		AIState.PATROL:
			_handle_patrol_state()
		AIState.DETECTION:
			_handle_detection_state()
		AIState.CHASE:
			_handle_chase_state()
		AIState.SEARCH:
			_handle_search_state(delta)

func _handle_idle_state(delta):
	idle_timer -= delta
	if idle_timer <= 0.0:
		_transition_to_patrol()

func _handle_patrol_state():
	# Check if we've reached our patrol target
	if navigation_agent.is_navigation_finished():
		_transition_to_idle()
	# Check for player detection while patrolling
	elif target_player and _has_line_of_sight_to_player():
		_transition_to_chase()

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
		if current_state == AIState.PATROL:
			print("Navigation finished - patrol complete")
	else:
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var direction: Vector2 = (next_path_position - global_position).normalized()
		
		if current_state == AIState.PATROL and randf() < 0.1:  # Only log 10% of the time to avoid spam
			print("Patrolling: current=", global_position, " next=", next_path_position, " direction=", direction)
		
		var desired_speed: float = max_speed
		if current_state == AIState.SEARCH or current_state == AIState.PATROL:
			desired_speed = patrol_speed
		
		current_speed = move_toward(current_speed, desired_speed, acceleration * delta)
		target_velocity = direction * current_speed
		
		if target_velocity.length() > 0:
			var target_angle = target_velocity.angle() + PI/2
			var angle_difference = angle_difference(rotation, target_angle)
			
			# Improved turning system similar to player
			var effective_turn_speed: float
			
			if abs(current_speed) < min_turn_speed:
				# Allow turning even at very low speeds
				effective_turn_speed = stationary_turn_speed
			else:
				# Speed-dependent turning with better low-speed handling
				var speed_factor = min(abs(current_speed) / max_speed, 1.0)
				var turn_curve = 0.4 + (speed_factor * 0.6)  # Range from 0.4 to 1.0
				effective_turn_speed = turn_speed * turn_curve
			
			# Apply turning with improved responsiveness
			var turn_amount = sign(angle_difference) * min(abs(angle_difference), effective_turn_speed * delta)
			rotation += turn_amount
	
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
	print("Navigation target set to: ", target_pos)
	#print("Navigation agent enabled: ", navigation_agent.enabled)
	print("Navigation map available: ", navigation_agent.get_navigation_map() != RID())
	await get_tree().physics_frame
	print("Path computed, distance to target: ", navigation_agent.distance_to_target())
	print("Is navigation finished: ", navigation_agent.is_navigation_finished())

func _initialize_patrol():
	# Get road positions from the map generator
	await get_tree().physics_frame
	var map_generator = get_node("../../MapGenerator")
	if not map_generator:
		print("MapGenerator not found! Trying different path...")
		map_generator = get_node("../MapGenerator")
	
	if map_generator and map_generator.has_method("get_road_grid"):
		var road_grid = map_generator.get_road_grid()
		var map_width = map_generator.map_width
		var map_height = map_generator.map_height
		var tile_size = 64
		
		print("Map size: ", map_width, "x", map_height)
		print("Road grid size: ", road_grid.size())
		
		# Build list of road positions
		road_positions.clear()
		for x in range(map_width):
			for y in range(map_height):
				if x < road_grid.size() and y < road_grid[x].size():
					if road_grid[x][y] != 0:  # Not empty
						var world_pos = Vector2(x * tile_size + tile_size/2, y * tile_size + tile_size/2)
						road_positions.append(world_pos)
		
		print("AI initialized with ", road_positions.size(), " patrol positions")
		print("AI current position: ", global_position)
		if road_positions.size() > 0:
			print("Sample positions: ", road_positions.slice(0, min(5, road_positions.size())))
	else:
		print("Failed to get road grid from map generator!")

func _get_random_patrol_target() -> Vector2:
	if road_positions.size() == 0:
		print("No road positions available!")
		return global_position
	
	print("AI at: ", global_position, " choosing from ", road_positions.size(), " positions")
	
	# Choose a random road position that's not too close to current position
	var attempts = 20
	var min_distance = 150.0  # Reduced min distance
	var current_pos = global_position
	
	for attempt in range(attempts):
		var random_pos = road_positions[randi() % road_positions.size()]
		var distance = current_pos.distance_to(random_pos)
		print("Attempt ", attempt, ": considering ", random_pos, " distance: ", distance)
		# Make sure we don't select our current position (with small tolerance)
		if distance >= min_distance and distance > 10.0:
			print("Selected patrol target: ", random_pos, " (distance: ", distance, ")")
			return random_pos
	
	# If no distant position found, find the furthest available position
	var furthest_pos = road_positions[0]
	var max_distance = 0.0
	
	for pos in road_positions:
		var distance = current_pos.distance_to(pos)
		if distance > max_distance:
			max_distance = distance
			furthest_pos = pos
	
	print("Using furthest position: ", furthest_pos, " (distance: ", max_distance, ")")
	return furthest_pos

func _transition_to_idle():
	current_state = AIState.IDLE
	target_player = null
	idle_timer = idle_time

func _transition_to_patrol():
	current_state = AIState.PATROL
	patrol_target = _get_random_patrol_target()
	_set_navigation_target(patrol_target)
	print("AI patrolling to: ", patrol_target, " current position:", position)

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
	elif current_state == AIState.PATROL:
		_transition_to_idle()

func get_current_state_name() -> String:
	match current_state:
		AIState.IDLE:
			return "IDLE"
		AIState.PATROL:
			return "PATROL"
		AIState.DETECTION:
			return "DETECTION"
		AIState.CHASE:
			return "CHASE"
		AIState.SEARCH:
			return "SEARCH"
		_:
			return "UNKNOWN"
