extends Node2D

@onready var road_layer: TileMapLayer = $RoadLayer
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

@export var map_width: int = 30
@export var map_height: int = 30
@export var num_main_roads: int = 3
@export var residential_block_size: int = 8
@export var connection_density: float = 0.3

# Road network data
var main_roads: Array = []
var residential_blocks: Array = []
var road_grid: Array[Array] = []
var tile_ids = {}

# Road types for hierarchy
enum RoadType {
	EMPTY,
	MAIN_ROAD,
	RESIDENTIAL,
	CONNECTOR
}

func _ready():
	setup_tiles()
	generate_hybrid_map()

func setup_tiles():
	# Cache tile IDs from tileset
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

func find_tile_by_name(texture_name: String) -> int:
	var tileset = road_layer.tile_set
	if not tileset:
		return -1
		
	for i in range(tileset.get_source_count()):
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			if atlas_source.texture and atlas_source.texture.resource_path.contains(texture_name):
				return source_id
	return -1

func generate_hybrid_map():
	if not road_layer:
		print("Error: RoadLayer not found!")
		return
	
	road_layer.clear()
	initialize_road_grid()
	
	print("=== Hybrid Road Generation ===")
	
	# Phase 1: Generate main road skeleton
	generate_main_roads()
	print("Phase 1: Generated ", main_roads.size(), " main roads")
	
	# Phase 2: Create residential blocks
	generate_residential_blocks()
	print("Phase 2: Generated ", residential_blocks.size(), " residential blocks")
	
	# Phase 3: Add connecting roads
	generate_connecting_roads()
	print("Phase 3: Generated connecting roads")
	
	# Phase 4: Place appropriate tiles using local WFC-style analysis
	place_road_tiles()
	print("Phase 4: Placed road tiles")
	
	# Phase 5: Generate navigation region for AI pathfinding
	generate_navigation_region()
	print("Phase 5: Generated navigation region")

func initialize_road_grid():
	road_grid = []
	for x in range(map_width):
		road_grid.append([])
		for y in range(map_height):
			road_grid[x].append(RoadType.EMPTY)

func generate_main_roads():
	main_roads = []
	
	# Generate main arterial roads that cross the map
	for i in range(num_main_roads):
		if i == 0:
			# Main horizontal road through center
			var y = map_height / 2
			for x in range(map_width):
				road_grid[x][y] = RoadType.MAIN_ROAD
			main_roads.append({"type": "horizontal", "position": y, "start": 0, "end": map_width - 1})
		
		elif i == 1:
			# Main vertical road through center
			var x = map_width / 2
			for y in range(map_height):
				road_grid[x][y] = RoadType.MAIN_ROAD
			main_roads.append({"type": "vertical", "position": x, "start": 0, "end": map_height - 1})
		
		else:
			# Additional arterial roads
			if randf() < 0.5:
				# Horizontal road
				var y = randi_range(5, map_height - 6)
				for x in range(map_width):
					if road_grid[x][y] == RoadType.EMPTY:
						road_grid[x][y] = RoadType.MAIN_ROAD
				main_roads.append({"type": "horizontal", "position": y, "start": 0, "end": map_width - 1})
			else:
				# Vertical road
				var x = randi_range(5, map_width - 6)
				for y in range(map_height):
					if road_grid[x][y] == RoadType.EMPTY:
						road_grid[x][y] = RoadType.MAIN_ROAD
				main_roads.append({"type": "vertical", "position": x, "start": 0, "end": map_height - 1})

func generate_residential_blocks():
	residential_blocks = []
	
	# Create rectangular residential areas between main roads
	var block_attempts = 20
	
	for attempt in range(block_attempts):
		var block_x = randi_range(2, map_width - residential_block_size - 2)
		var block_y = randi_range(2, map_height - residential_block_size - 2)
		
		# Check if area is mostly empty
		var empty_count = 0
		var total_cells = residential_block_size * residential_block_size
		
		for x in range(block_x, block_x + residential_block_size):
			for y in range(block_y, block_y + residential_block_size):
				if x < map_width and y < map_height and road_grid[x][y] == RoadType.EMPTY:
					empty_count += 1
		
		# If area is at least 70% empty, create residential block
		if empty_count >= total_cells * 0.7:
			create_residential_block(block_x, block_y, residential_block_size)
			residential_blocks.append({
				"x": block_x, 
				"y": block_y, 
				"size": residential_block_size
			})

func create_residential_block(start_x: int, start_y: int, size: int):
	# Create perimeter roads around the block
	for i in range(size):
		# Top and bottom edges
		if start_x + i < map_width:
			if start_y >= 0 and start_y < map_height:
				road_grid[start_x + i][start_y] = RoadType.RESIDENTIAL
			if start_y + size - 1 < map_height:
				road_grid[start_x + i][start_y + size - 1] = RoadType.RESIDENTIAL
		
		# Left and right edges  
		if start_y + i < map_height:
			if start_x >= 0 and start_x < map_width:
				road_grid[start_x][start_y + i] = RoadType.RESIDENTIAL
			if start_x + size - 1 < map_width:
				road_grid[start_x + size - 1][start_y + i] = RoadType.RESIDENTIAL
	
	# Add internal roads for larger blocks
	if size >= 12:
		var mid = size / 2
		# Internal horizontal road
		for x in range(start_x + 1, start_x + size - 1):
			if x < map_width and start_y + mid < map_height:
				road_grid[x][start_y + mid] = RoadType.RESIDENTIAL
		
		# Internal vertical road
		for y in range(start_y + 1, start_y + size - 1):
			if start_x + mid < map_width and y < map_height:
				road_grid[start_x + mid][y] = RoadType.RESIDENTIAL

func generate_connecting_roads():
	# Add random connecting roads between main roads and residential areas
	var connection_attempts = int(map_width * map_height * connection_density / 100)
	
	for attempt in range(connection_attempts):
		var start_x = randi() % map_width
		var start_y = randi() % map_height
		
		# Only start from existing roads
		if road_grid[start_x][start_y] != RoadType.EMPTY:
			create_connecting_path(start_x, start_y)

func create_connecting_path(start_x: int, start_y: int):
	var length = randi_range(3, 8)
	var direction = randi() % 4  # 0=N, 1=E, 2=S, 3=W
	
	var x = start_x
	var y = start_y
	
	for i in range(length):
		if x >= 0 and x < map_width and y >= 0 and y < map_height:
			if road_grid[x][y] == RoadType.EMPTY:
				road_grid[x][y] = RoadType.CONNECTOR
			
			# Small chance to change direction
			if randf() < 0.2:
				direction = randi() % 4
		
		# Move in current direction
		match direction:
			0: y -= 1  # North
			1: x += 1  # East
			2: y += 1  # South
			3: x -= 1  # West

func place_road_tiles():
	for x in range(map_width):
		for y in range(map_height):
			if road_grid[x][y] != RoadType.EMPTY:
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
		0, 1:
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
	return road_grid[x][y] != RoadType.EMPTY

func get_tile_id_for_type(tile_type: String) -> int:
	if tile_type in tile_ids:
		return tile_ids[tile_type]
	return tile_ids["horizontal"]  # fallback

func generate_navigation_region():
	if not navigation_region:
		print("Warning: NavigationRegion2D not found!")
		return
	
	var navigation_polygon = NavigationPolygon.new()
	var road_cells = []
	
	# Collect all road cells
	for x in range(map_width):
		for y in range(map_height):
			if road_grid[x][y] != RoadType.EMPTY:
				road_cells.append(Vector2i(x, y))
	
	if road_cells.size() == 0:
		print("No road cells found for navigation!")
		return
	
	# Create navigation polygons for road areas
	var tile_size = road_layer.tile_set.tile_size
	var polygons = []
	
	# Group connected road cells into larger polygons
	var processed_cells = {}
	
	for cell in road_cells:
		if cell in processed_cells:
			continue
		
		var connected_group = find_connected_road_cells(cell, road_cells, processed_cells)
		if connected_group.size() > 0:
			var polygon = create_polygon_from_cells(connected_group, tile_size)
			if polygon.size() >= 3:
				polygons.append(polygon)
	
	# Add polygons to navigation polygon
	for i in range(polygons.size()):
		navigation_polygon.add_outline(polygons[i])
	
	navigation_polygon.make_polygons_from_outlines()
	navigation_region.navigation_polygon = navigation_polygon

func find_connected_road_cells(start_cell: Vector2i, all_cells: Array, processed: Dictionary) -> Array:
	var connected = []
	var stack = [start_cell]
	
	while stack.size() > 0:
		var current = stack.pop_back()
		if current in processed:
			continue
		
		processed[current] = true
		connected.append(current)
		
		# Check 4-directional neighbors
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			if neighbor in all_cells and not neighbor in processed:
				stack.append(neighbor)
	
	return connected

func create_polygon_from_cells(cells: Array, tile_size: Vector2i) -> PackedVector2Array:
	if cells.size() == 0:
		return PackedVector2Array()
	
	# Find bounding box
	var min_x = cells[0].x
	var max_x = cells[0].x
	var min_y = cells[0].y
	var max_y = cells[0].y
	
	for cell in cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	
	# Create a simple rectangular polygon for the connected area
	var polygon = PackedVector2Array()
	polygon.append(Vector2(min_x * tile_size.x, min_y * tile_size.y))
	polygon.append(Vector2((max_x + 1) * tile_size.x, min_y * tile_size.y))
	polygon.append(Vector2((max_x + 1) * tile_size.x, (max_y + 1) * tile_size.y))
	polygon.append(Vector2(min_x * tile_size.x, (max_y + 1) * tile_size.y))
	
	return polygon