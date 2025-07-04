extends Node2D

@onready var road_layer: TileMapLayer = $RoadLayer

enum GenerationType {
	SIMPLE_CROSS,
	GRID_NETWORK,
	RANDOM_PATHS,
	CONNECTED_NETWORK
}

@export var generation_type: GenerationType = GenerationType.RANDOM_PATHS
@export var map_width: int = 30
@export var map_height: int = 30
@export var road_density: float = 0.3
@export var intersection_chance: float = 0.4

func _ready():
	generate_map()

var road_network: Array[Array] = []
var tile_ids = {}

func generate_map():
	if not road_layer:
		print("Error: RoadLayer not found!")
		return
		
	var tileset = road_layer.tile_set
	if not tileset:
		print("Error: TileSet not found!")
		return
	
	# Clear existing tiles
	road_layer.clear()
	
	# Initialize road network grid
	road_network = []
	for x in range(map_width):
		road_network.append([])
		for y in range(map_height):
			road_network[x].append(false)
	
	# Find all tile types
	cache_tile_ids()
	
	match generation_type:
		GenerationType.SIMPLE_CROSS:
			generate_cross_road()
		GenerationType.GRID_NETWORK:
			generate_grid_network()
		GenerationType.RANDOM_PATHS:
			generate_random_paths()
		GenerationType.CONNECTED_NETWORK:
			generate_connected_network()
	
	# After generating road network, place appropriate tiles
	place_road_tiles()

func generate_cross_road():
	var center_x = map_width / 2
	var center_y = map_height / 2
	
	for x in range(map_width):
		for y in range(map_height):
			if x == center_x or y == center_y:
				road_network[x][y] = true

func generate_grid_network():
	var grid_spacing = 5  # Roads every 5 tiles
	
	for x in range(0, map_width, grid_spacing):
		for y in range(0, map_height, grid_spacing):
			# Create horizontal roads
			if randf() < road_density:
				for i in range(grid_spacing):
					if x + i < map_width:
						road_network[x + i][y] = true
			
			# Create vertical roads
			if randf() < road_density:
				for i in range(grid_spacing):
					if y + i < map_height:
						road_network[x][y + i] = true

func generate_random_paths():
	var num_paths = int(map_width * map_height * road_density / 10)
	
	for i in range(num_paths):
		var start_x = randi() % map_width
		var start_y = randi() % map_height
		var length = randi_range(5, 15)
		var direction = randi() % 4  # 0=right, 1=down, 2=left, 3=up
		
		var current_x = start_x
		var current_y = start_y
		
		for j in range(length):
			if current_x >= 0 and current_x < map_width and current_y >= 0 and current_y < map_height:
				road_network[current_x][current_y] = true
				
				# Random chance to change direction
				if randf() < 0.1:
					direction = randi() % 4
			
			match direction:
				0: current_x += 1  # right
				1: current_y += 1  # down
				2: current_x -= 1  # left
				3: current_y -= 1  # up

func generate_connected_network():
	# Create main arterial roads
	var main_x_roads = [map_width / 3, 2 * map_width / 3]
	var main_y_roads = [map_height / 3, 2 * map_height / 3]
	
	# Create main vertical roads
	for x in main_x_roads:
		for y in range(map_height):
			road_network[x][y] = true
	
	# Create main horizontal roads
	for y in main_y_roads:
		for x in range(map_width):
			road_network[x][y] = true
	
	# Add some random connecting roads
	generate_random_paths()

func cache_tile_ids():
	tile_ids = {
		"horizontal": find_tile_by_name("LigneHorizontale"),
		"vertical": find_tile_by_name("LigneVerticale"),
		"intersection": find_tile_by_name("Croisement_ligne"),
		"corner_top_left": find_tile_by_name("CoinHautGauche_ligne"),
		"corner_top_right": find_tile_by_name("CoinHautDroit_ligne"),
		"corner_bottom_left": find_tile_by_name("CoinBasGauche_ligne"),
		"corner_bottom_right": find_tile_by_name("CoinBasDroite_ligne"),
		"t_top": find_tile_by_name("T_Haut"),
		"t_bottom": find_tile_by_name("T_Bas"),
		"t_left": find_tile_by_name("T_Gauche"),
		"t_right": find_tile_by_name("T_Droit")
	}
	
	print("Cached tile IDs:")
	for key in tile_ids:
		print(key, ": ", tile_ids[key])

func find_tile_by_name(texture_name: String) -> int:
	var tileset = road_layer.tile_set
	if not tileset:
		return -1
		
	# Search through all sources
	for i in range(tileset.get_source_count()):
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			if atlas_source.texture:
				if atlas_source.texture.resource_path.contains(texture_name):
					return source_id
	
	return -1

func place_road_tiles():
	for x in range(map_width):
		for y in range(map_height):
			if road_network[x][y]:
				var tile_type = determine_tile_type(x, y)
				var tile_id = get_tile_id_for_type(tile_type)
				if tile_id != -1:
					road_layer.set_cell(Vector2i(x, y), tile_id, Vector2i(0, 0))

func determine_tile_type(x: int, y: int) -> String:
	var north = has_road(x, y - 1)
	var south = has_road(x, y + 1)
	var east = has_road(x + 1, y)
	var west = has_road(x - 1, y)
	
	var connections = 0
	if north: connections += 1
	if south: connections += 1
	if east: connections += 1
	if west: connections += 1
	
	# Determine tile type based on connections
	match connections:
		0:
			return "horizontal"  # Single tile, default to horizontal
		1:
			return "horizontal" if east or west else "vertical"
		2:
			if north and south:
				return "vertical"
			elif east and west:
				return "horizontal"
			elif north and east:
				return "corner_bottom_left"
			elif north and west:
				return "corner_bottom_right"
			elif south and east:
				return "corner_top_left"
			elif south and west:
				return "corner_top_right"
		3:
			if not north:
				return "t_bottom"
			elif not south:
				return "t_top"
			elif not east:
				return "t_left"
			elif not west:
				return "t_right"
		4:
			return "intersection"
	
	return "horizontal"

func has_road(x: int, y: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return false
	return road_network[x][y]

func get_tile_id_for_type(tile_type: String) -> int:
	if tile_type in tile_ids:
		return tile_ids[tile_type]
	return tile_ids["horizontal"]  # fallback
