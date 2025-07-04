extends Node2D

@export var player_scene: PackedScene
@export var ai_scene: PackedScene
@export var tile_size: int = 64

var map_generator: Node2D
var spawned_player: CharacterBody2D
var spawned_ai: CharacterBody2D

func _ready():
	call_deferred("spawn_vehicles")

func spawn_vehicles():
	# Wait for map generation to complete
	await get_tree().process_frame
	
	map_generator = get_parent().get_node("MapGenerator")
	if not map_generator:
		print("MapGenerator not found!")
		return
	
	# Wait a bit more for map generation to complete
	await get_tree().create_timer(0.1).timeout
	
	var road_positions = find_road_positions()
	if road_positions.size() < 2:
		print("Not enough road positions found for spawning!")
		return
	
	# Spawn player at first available road position
	spawn_player(road_positions[0])
	
	# Spawn AI at a position away from player
	var ai_data = find_distant_spawn_position(road_positions, road_positions[0])
	spawn_ai(ai_data)

func find_road_positions() -> Array[Dictionary]:
	var road_positions: Array[Dictionary] = []
	
	if not map_generator.has_method("get_road_grid"):
		print("MapGenerator doesn't have get_road_grid method!")
		return road_positions
	
	var road_grid = map_generator.get_road_grid()
	var map_width = map_generator.map_width
	var map_height = map_generator.map_height
	
	# Find all road tile positions with their directions
	for x in range(map_width):
		for y in range(map_height):
			if x < road_grid.size() and y < road_grid[x].size():
				if road_grid[x][y] != 0:  # Not empty
					var world_pos = Vector2(x * tile_size + tile_size/2, y * tile_size + tile_size/2)
					var road_direction = get_road_direction(road_grid, x, y, map_width, map_height)
					road_positions.append({
						"position": world_pos,
						"rotation": road_direction
					})
	
	print("Found ", road_positions.size(), " road positions")
	return road_positions

func get_road_direction(road_grid: Array, x: int, y: int, map_width: int, map_height: int) -> float:
	# Check adjacent tiles to determine road direction
	var north = has_road_at(road_grid, x, y - 1, map_width, map_height)
	var south = has_road_at(road_grid, x, y + 1, map_width, map_height)
	var east = has_road_at(road_grid, x + 1, y, map_width, map_height)
	var west = has_road_at(road_grid, x - 1, y, map_width, map_height)
	
	# Determine primary direction based on connections
	# Return rotation in radians (0 = facing up/north)
	
	if north and south:
		# Vertical road - face north
		return 0.0
	elif east and west:
		# Horizontal road - face east  
		return PI/2
	elif north and east:
		# Corner - face northeast
		return PI/4
	elif north and west:
		# Corner - face northwest
		return -PI/4
	elif south and east:
		# Corner - face southeast
		return 3*PI/4
	elif south and west:
		# Corner - face southwest
		return -3*PI/4
	elif north:
		# Dead end opening north - face north
		return 0.0
	elif south:
		# Dead end opening south - face south
		return PI
	elif east:
		# Dead end opening east - face east
		return PI/2
	elif west:
		# Dead end opening west - face west
		return -PI/2
	else:
		# Default facing north
		return 0.0

func has_road_at(road_grid: Array, x: int, y: int, map_width: int, map_height: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return false
	if x >= road_grid.size() or y >= road_grid[x].size():
		return false
	return road_grid[x][y] != 0

func find_distant_spawn_position(positions: Array[Dictionary], player_data: Dictionary) -> Dictionary:
	var best_position = positions[0]
	var max_distance = 0.0
	
	for pos_data in positions:
		var distance = player_data.position.distance_to(pos_data.position)
		if distance > max_distance:
			max_distance = distance
			best_position = pos_data
	
	return best_position

func spawn_player(spawn_data: Dictionary):
	if not player_scene:
		print("Player scene not set!")
		return
	
	spawned_player = player_scene.instantiate()
	spawned_player.global_position = spawn_data.position
	spawned_player.rotation = spawn_data.rotation
	get_parent().add_child(spawned_player)
	
	# Update camera to follow player
	var camera = get_parent().get_node("Camera")
	if camera and camera.has_method("set_target"):
		camera.set_target(spawned_player)
	
	print("Player spawned at: ", spawn_data.position, " facing: ", rad_to_deg(spawn_data.rotation), " degrees")

func spawn_ai(spawn_data: Dictionary):
	if not ai_scene:
		print("AI scene not set!")
		return
	
	spawned_ai = ai_scene.instantiate()
	spawned_ai.global_position = spawn_data.position
	spawned_ai.rotation = spawn_data.rotation
	get_parent().add_child(spawned_ai)
	
	print("AI spawned at: ", spawn_data.position, " facing: ", rad_to_deg(spawn_data.rotation), " degrees")

func get_player() -> CharacterBody2D:
	return spawned_player

func get_ai() -> CharacterBody2D:
	return spawned_ai