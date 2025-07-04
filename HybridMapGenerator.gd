extends Node2D

@onready var road_layer: TileMapLayer = $RoadLayer
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

@export var map_width: int = 30
@export var map_height: int = 30
@export var num_main_roads: int = 3
@export var residential_block_size: int = 8
@export var connection_density: float = 0.3
@export var border_margin: int = 2

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
		"t_right": find_tile_by_name("T_Droit"),
		"deadend_north": find_tile_by_name("Ligne_noir"),
		"deadend_east": find_tile_by_name("Ligne_noir"),
		"deadend_south": find_tile_by_name("Ligne_noir"),
		"deadend_west": find_tile_by_name("Ligne_noir"),
		"deadend_block": find_tile_by_name("Ligne_noir")
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
	
	# Phase 4.5: Close off dead-ends properly
	close_deadends()
	print("Phase 4.5: Closed dead-ends")
	
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
			# Main horizontal road through center (with border margin)
			var y = map_height / 2
			for x in range(border_margin, map_width - border_margin):
				road_grid[x][y] = RoadType.MAIN_ROAD
			main_roads.append({"type": "horizontal", "position": y, "start": border_margin, "end": map_width - border_margin - 1})
		
		elif i == 1:
			# Main vertical road through center (with border margin)
			var x = map_width / 2
			for y in range(border_margin, map_height - border_margin):
				road_grid[x][y] = RoadType.MAIN_ROAD
			main_roads.append({"type": "vertical", "position": x, "start": border_margin, "end": map_height - border_margin - 1})
		
		else:
			# Additional arterial roads (with border margin)
			if randf() < 0.5:
				# Horizontal road
				var y = randi_range(border_margin + 3, map_height - border_margin - 4)
				for x in range(border_margin, map_width - border_margin):
					if road_grid[x][y] == RoadType.EMPTY:
						road_grid[x][y] = RoadType.MAIN_ROAD
				main_roads.append({"type": "horizontal", "position": y, "start": border_margin, "end": map_width - border_margin - 1})
			else:
				# Vertical road
				var x = randi_range(border_margin + 3, map_width - border_margin - 4)
				for y in range(border_margin, map_height - border_margin):
					if road_grid[x][y] == RoadType.EMPTY:
						road_grid[x][y] = RoadType.MAIN_ROAD
				main_roads.append({"type": "vertical", "position": x, "start": border_margin, "end": map_height - border_margin - 1})

func generate_residential_blocks():
	residential_blocks = []
	
	# Create rectangular residential areas between main roads
	var block_attempts = 20
	
	for attempt in range(block_attempts):
		var block_x = randi_range(border_margin, map_width - residential_block_size - border_margin)
		var block_y = randi_range(border_margin, map_height - residential_block_size - border_margin)
		
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
		var start_x = randi_range(border_margin, map_width - border_margin - 1)
		var start_y = randi_range(border_margin, map_height - border_margin - 1)
		
		# Only start from existing roads
		if road_grid[start_x][start_y] != RoadType.EMPTY:
			create_connecting_path(start_x, start_y)

func create_connecting_path(start_x: int, start_y: int):
	var length = randi_range(3, 8)
	var direction = randi() % 4  # 0=N, 1=E, 2=S, 3=W
	
	var x = start_x
	var y = start_y
	
	for i in range(length):
		# Ensure we stay within the border margins
		if x >= border_margin and x < map_width - border_margin and y >= border_margin and y < map_height - border_margin:
			if road_grid[x][y] == RoadType.EMPTY:
				road_grid[x][y] = RoadType.CONNECTOR
			
			# Small chance to change direction
			if randf() < 0.2:
				direction = randi() % 4
		
		# Move in current direction, but stop if we hit the border
		var next_x = x
		var next_y = y
		match direction:
			0: next_y -= 1  # North
			1: next_x += 1  # East
			2: next_y += 1  # South
			3: next_x -= 1  # West
		
		# Only move if the next position is within border margins
		if next_x >= border_margin and next_x < map_width - border_margin and next_y >= border_margin and next_y < map_height - border_margin:
			x = next_x
			y = next_y
		else:
			# Hit the border, stop generating this path
			break

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
		0:
			# Isolated road tile (shouldn't happen normally)
			return "horizontal"
		1:
			# Dead-end - determine which direction it opens to
			if north:
				return "deadend_south"  # Road opens to the north, closed on south
			elif south:
				return "deadend_north"  # Road opens to the south, closed on north
			elif east:
				return "deadend_west"   # Road opens to the east, closed on west
			elif west:
				return "deadend_east"   # Road opens to the west, closed on east
			else:
				return "horizontal"     # Fallback
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
	
	# Clear any existing children from navigation region
	for child in navigation_region.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Setup navigation using NavigationServer2D approach
	var navigation_mesh = NavigationPolygon.new()
	navigation_mesh.agent_radius = 10.0
	
	var source_geometry = NavigationMeshSourceGeometryData2D.new()
	
	# Create RID for the region
	var region_rid = NavigationServer2D.region_create()
	NavigationServer2D.region_set_enabled(region_rid, true)
	NavigationServer2D.region_set_map(region_rid, get_world_2d().get_navigation_map())
	
	# Store references for callbacks
	navigation_region.set_meta("navigation_mesh", navigation_mesh)
	navigation_region.set_meta("source_geometry", source_geometry)
	navigation_region.set_meta("region_rid", region_rid)
	
	# Parse source geometry and bake
	parse_road_source_geometry(navigation_mesh, source_geometry)

func parse_road_source_geometry(navigation_mesh: NavigationPolygon, source_geometry: NavigationMeshSourceGeometryData2D):
	source_geometry.clear()
	
	var road_cells = []
	
	# Collect all road cells
	for x in range(map_width):
		for y in range(map_height):
			if road_grid[x][y] != RoadType.EMPTY:
				road_cells.append(Vector2i(x, y))
	
	if road_cells.size() == 0:
		print("No road cells found for navigation!")
		return
	
	var tile_size = road_layer.tile_set.tile_size
	
	print("Creating traversable outlines for ", road_cells.size(), " road tiles")
	print("Using full tile size: ", tile_size, " for navigation areas")
	
	# Add traversable outlines for each road tile - use full tile size for perfect connection
	for cell in road_cells:
		var world_x = cell.x * tile_size.x
		var world_y = cell.y * tile_size.y
		
		# Create traversable outline covering the entire tile for perfect connection
		var road_outline = PackedVector2Array()
		road_outline.append(Vector2(world_x, world_y))                                    # top-left
		road_outline.append(Vector2(world_x + tile_size.x, world_y))                     # top-right  
		road_outline.append(Vector2(world_x + tile_size.x, world_y + tile_size.y))       # bottom-right
		road_outline.append(Vector2(world_x, world_y + tile_size.y))                     # bottom-left
		
		source_geometry.add_traversable_outline(road_outline)
		
		# Debug first few outlines
		if road_cells.find(cell) < 3:
			print("Road tile ", cell, " at world pos (", world_x, ",", world_y, ")")
			print("  Full tile outline: ", road_outline)
	
	print("Added ", road_cells.size(), " traversable outlines")
	
	# Start async baking
	NavigationServer2D.bake_from_source_geometry_data_async(
		navigation_mesh,
		source_geometry,
		on_navigation_baking_done
	)

func on_navigation_baking_done():
	print("Navigation mesh baking completed!")
	
	# Get stored references
	var navigation_mesh = navigation_region.get_meta("navigation_mesh")
	var region_rid = navigation_region.get_meta("region_rid")
	
	# Update the region with the baked navigation mesh
	NavigationServer2D.region_set_navigation_polygon(region_rid, navigation_mesh)
	
	# Also set it on the NavigationRegion2D node for compatibility
	navigation_region.navigation_polygon = navigation_mesh
	
	print("- Navigation mesh polygon count: ", navigation_mesh.get_polygon_count())
	print("- Navigation region updated with RID: ", region_rid)


func close_deadends():
	# Find all dead-end roads and ensure they're properly closed off
	for x in range(map_width):
		for y in range(map_height):
			if road_grid[x][y] != RoadType.EMPTY:
				var connections = count_road_connections(x, y)
				if connections == 1:
					# This is a dead-end, ensure it's closed off
					close_deadend_tile(x, y)

func count_road_connections(x: int, y: int) -> int:
	var connections = 0
	if has_road(x, y - 1): connections += 1  # North
	if has_road(x, y + 1): connections += 1  # South
	if has_road(x + 1, y): connections += 1  # East
	if has_road(x - 1, y): connections += 1  # West
	return connections

func close_deadend_tile(x: int, y: int):
	# For a dead-end tile, we need to ensure vehicles can't drive past it
	# We do this by placing blocking tiles (black/noir tiles) at the dead-end
	
	# Find which direction the road doesn't connect to
	var north = has_road(x, y - 1)
	var south = has_road(x, y + 1)
	var east = has_road(x + 1, y)
	var west = has_road(x - 1, y)
	
	# Place blocking tiles in the direction that should be closed
	if not north and y > 0:
		# Close off north - place black tile north of this position
		place_blocking_tile(x, y - 1)
	if not south and y < map_height - 1:
		# Close off south - place black tile south of this position  
		place_blocking_tile(x, y + 1)
	if not east and x < map_width - 1:
		# Close off east - place black tile east of this position
		place_blocking_tile(x + 1, y)
	if not west and x > 0:
		# Close off west - place black tile west of this position
		place_blocking_tile(x - 1, y)

func place_blocking_tile(x: int, y: int):
	# Only place blocking tile if the position is currently empty
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		if road_grid[x][y] == RoadType.EMPTY:
			# Place a black/blocking tile
			var tile_id = get_tile_id_for_type("deadend_block")
			if tile_id != -1:
				road_layer.set_cell(Vector2i(x, y), tile_id, Vector2i(0, 0))


func get_road_grid() -> Array[Array]:
	return road_grid
