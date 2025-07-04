extends Node2D

@onready var road_layer: TileMapLayer = $RoadLayer

@export var map_width: int = 30
@export var map_height: int = 30
@export var max_iterations: int = 1000

# WFC state for each cell
var cell_possibilities: Array[Array] = []
var collapsed_cells: Array[Array] = []

# Tile data
var tiles = {}
var tile_weights = {}
var adjacency_rules = {}

# Tile types based on connection points (N, E, S, W)
enum TileType {
	EMPTY,           # No connections: 0000
	HORIZONTAL,      # East-West:      0110  
	VERTICAL,        # North-South:    1001
	CORNER_NE,       # North-East:     1010
	CORNER_SE,       # South-East:     0011
	CORNER_SW,       # South-West:     0101
	CORNER_NW,       # North-West:     1100
	T_NORTH,         # T pointing N:   1110
	T_EAST,          # T pointing E:   1011
	T_SOUTH,         # T pointing S:   0111
	T_WEST,          # T pointing W:   1101
	INTERSECTION     # All directions: 1111
}

func _ready():
	setup_tiles()
	setup_weights()
	setup_adjacency_rules()
	generate_wfc_map()

func setup_tiles():
	# Analyze tileset and categorize by connection patterns
	tiles = {
		TileType.EMPTY: [],
		TileType.HORIZONTAL: [],
		TileType.VERTICAL: [],
		TileType.CORNER_NE: [],
		TileType.CORNER_SE: [],
		TileType.CORNER_SW: [],
		TileType.CORNER_NW: [],
		TileType.T_NORTH: [],
		TileType.T_EAST: [],
		TileType.T_SOUTH: [],
		TileType.T_WEST: [],
		TileType.INTERSECTION: []
	}
	
	# Map tile names to types based on French naming
	var tile_mappings = {
		"LigneHorizontale": TileType.HORIZONTAL,
		"LigneVerticale": TileType.VERTICAL,
		"CoinHautDroit": TileType.CORNER_NE,
		"CoinBasDroit": TileType.CORNER_SE,
		"CoinBasGauche": TileType.CORNER_SW,
		"CoinHautGauche": TileType.CORNER_NW,
		"T_Haut": TileType.T_NORTH,
		"T_Droit": TileType.T_EAST,
		"T_Bas": TileType.T_SOUTH,
		"T_Gauche": TileType.T_WEST,
		"Croisement": TileType.INTERSECTION
	}
	
	var tileset = road_layer.tile_set
	if not tileset:
		print("Error: TileSet not found!")
		return
	
	# Find tiles in tileset
	for i in range(tileset.get_source_count()):
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			if atlas_source.texture:
				var texture_path = atlas_source.texture.resource_path
				
				for tile_name in tile_mappings:
					if texture_path.contains(tile_name):
						var tile_type = tile_mappings[tile_name]
						tiles[tile_type].append(source_id)
						print("Found tile: ", tile_name, " -> ", tile_type, " (ID: ", source_id, ")")
						break

func setup_weights():
	# Suburban layout weights - favor straight roads, minimize intersections
	tile_weights = {
		TileType.EMPTY: 0.8,           # More empty space
		TileType.HORIZONTAL: 0.5,      # High preference for straight roads
		TileType.VERTICAL: 0.5,        # High preference for straight roads
		TileType.CORNER_NE: 0.2,       # Higher corner frequency
		TileType.CORNER_SE: 0.2,
		TileType.CORNER_SW: 0.2,
		TileType.CORNER_NW: 0.2,
		TileType.T_NORTH: 0.04,        # Less common T-junctions
		TileType.T_EAST: 0.04,
		TileType.T_SOUTH: 0.04,
		TileType.T_WEST: 0.04,
		TileType.INTERSECTION: 0.02    # Rare intersections
	}

func setup_adjacency_rules():
	# Define which tile types can be adjacent (N, E, S, W directions)
	adjacency_rules = {}
	
	# For each tile type, define what can connect in each direction
	# Format: [north_compatible, east_compatible, south_compatible, west_compatible]
	
	var north_connectors = [TileType.VERTICAL, TileType.CORNER_SW, TileType.CORNER_SE, 
							TileType.T_NORTH, TileType.T_EAST, TileType.T_WEST, TileType.INTERSECTION]
	var east_connectors = [TileType.HORIZONTAL, TileType.CORNER_NW, TileType.CORNER_SW,
						   TileType.T_EAST, TileType.T_NORTH, TileType.T_SOUTH, TileType.INTERSECTION]
	var south_connectors = [TileType.VERTICAL, TileType.CORNER_NE, TileType.CORNER_NW,
							TileType.T_SOUTH, TileType.T_EAST, TileType.T_WEST, TileType.INTERSECTION]
	var west_connectors = [TileType.HORIZONTAL, TileType.CORNER_NE, TileType.CORNER_SE,
						   TileType.T_WEST, TileType.T_NORTH, TileType.T_SOUTH, TileType.INTERSECTION]
	
	adjacency_rules[TileType.EMPTY] = [[], [], [], []]
	adjacency_rules[TileType.HORIZONTAL] = [[], east_connectors, [], west_connectors]
	adjacency_rules[TileType.VERTICAL] = [north_connectors, [], south_connectors, []]
	adjacency_rules[TileType.CORNER_NE] = [north_connectors, east_connectors, [], []]
	adjacency_rules[TileType.CORNER_SE] = [[], east_connectors, south_connectors, []]
	adjacency_rules[TileType.CORNER_SW] = [[], [], south_connectors, west_connectors]
	adjacency_rules[TileType.CORNER_NW] = [north_connectors, [], [], west_connectors]
	adjacency_rules[TileType.T_NORTH] = [north_connectors, east_connectors, [], west_connectors]
	adjacency_rules[TileType.T_EAST] = [north_connectors, east_connectors, south_connectors, []]
	adjacency_rules[TileType.T_SOUTH] = [[], east_connectors, south_connectors, west_connectors]
	adjacency_rules[TileType.T_WEST] = [north_connectors, [], south_connectors, west_connectors]
	adjacency_rules[TileType.INTERSECTION] = [north_connectors, east_connectors, south_connectors, west_connectors]

func generate_wfc_map():
	if not road_layer:
		print("Error: RoadLayer not found!")
		return
	
	road_layer.clear()
	
	# Initialize WFC state
	initialize_wfc()
	
	# Add seed patterns for suburban layout
	add_seed_patterns()
	
	# Run WFC algorithm
	var iterations = 0
	while not is_fully_collapsed() and iterations < max_iterations:
		if not wfc_step():
			print("WFC failed at iteration: ", iterations)
			break
		iterations += 1
	
	print("WFC completed in ", iterations, " iterations")
	
	# Place tiles based on final state
	place_final_tiles()

func initialize_wfc():
	cell_possibilities = []
	collapsed_cells = []
	
	for x in range(map_width):
		cell_possibilities.append([])
		collapsed_cells.append([])
		for y in range(map_height):
			# Start with all tile types possible
			cell_possibilities[x].append(TileType.values())
			collapsed_cells[x].append(false)
	
	# Apply boundary constraints - edges must connect to roads
	apply_boundary_constraints()

func apply_boundary_constraints():
	# Force edges to have road connections pointing inward
	for x in range(map_width):
		for y in range(map_height):
			var edge_constraints = []
			
			# Top edge - must have south connection
			if y == 0:
				edge_constraints = [TileType.VERTICAL, TileType.CORNER_SW, TileType.CORNER_SE,
								   TileType.T_SOUTH, TileType.T_EAST, TileType.T_WEST, TileType.INTERSECTION]
			
			# Bottom edge - must have north connection  
			elif y == map_height - 1:
				edge_constraints = [TileType.VERTICAL, TileType.CORNER_NE, TileType.CORNER_NW,
								   TileType.T_NORTH, TileType.T_EAST, TileType.T_WEST, TileType.INTERSECTION]
			
			# Left edge - must have east connection
			elif x == 0:
				edge_constraints = [TileType.HORIZONTAL, TileType.CORNER_NE, TileType.CORNER_SE,
								   TileType.T_EAST, TileType.T_NORTH, TileType.T_SOUTH, TileType.INTERSECTION]
			
			# Right edge - must have west connection
			elif x == map_width - 1:
				edge_constraints = [TileType.HORIZONTAL, TileType.CORNER_NW, TileType.CORNER_SW,
								   TileType.T_WEST, TileType.T_NORTH, TileType.T_SOUTH, TileType.INTERSECTION]
			
			if edge_constraints.size() > 0:
				cell_possibilities[x][y] = edge_constraints

func add_seed_patterns():
	# Add main arterial roads for suburban layout
	var center_x = map_width / 2
	var center_y = map_height / 2
	
	# Main horizontal road
	for x in range(map_width):
		constrain_cell(x, center_y, [TileType.HORIZONTAL, TileType.INTERSECTION, 
									 TileType.T_NORTH, TileType.T_SOUTH])
	
	# Main vertical road
	for y in range(map_height):
		constrain_cell(center_x, y, [TileType.VERTICAL, TileType.INTERSECTION,
									 TileType.T_EAST, TileType.T_WEST])
	
	# Force intersection at center
	constrain_cell(center_x, center_y, [TileType.INTERSECTION])

func constrain_cell(x: int, y: int, allowed_types: Array):
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		var filtered = []
		for tile_type in cell_possibilities[x][y]:
			if tile_type in allowed_types:
				filtered.append(tile_type)
		cell_possibilities[x][y] = filtered

func wfc_step() -> bool:
	# Find cell with lowest entropy (fewest possibilities)
	var min_entropy = INF
	var min_cells = []
	
	for x in range(map_width):
		for y in range(map_height):
			if not collapsed_cells[x][y]:
				var entropy = cell_possibilities[x][y].size()
				if entropy == 0:
					return false  # Contradiction
				elif entropy < min_entropy:
					min_entropy = entropy
					min_cells = [Vector2i(x, y)]
				elif entropy == min_entropy:
					min_cells.append(Vector2i(x, y))
	
	if min_cells.is_empty():
		return false
	
	# Pick random cell from lowest entropy cells
	var chosen_cell = min_cells[randi() % min_cells.size()]
	
	# Collapse the cell using weighted selection
	collapse_cell(chosen_cell.x, chosen_cell.y)
	
	# Propagate constraints
	propagate_constraints(chosen_cell.x, chosen_cell.y)
	
	return true

func collapse_cell(x: int, y: int):
	var possibilities = cell_possibilities[x][y]
	
	# Weight-based selection
	var total_weight = 0.0
	for tile_type in possibilities:
		total_weight += tile_weights[tile_type]
	
	var random_weight = randf() * total_weight
	var current_weight = 0.0
	
	for tile_type in possibilities:
		current_weight += tile_weights[tile_type]
		if current_weight >= random_weight:
			cell_possibilities[x][y] = [tile_type]
			collapsed_cells[x][y] = true
			break

func propagate_constraints(x: int, y: int):
	var queue = [Vector2i(x, y)]
	
	while not queue.is_empty():
		var cell = queue.pop_front()
		var cx = cell.x
		var cy = cell.y
		
		if collapsed_cells[cx][cy]:
			var tile_type = cell_possibilities[cx][cy][0]
			var rules = adjacency_rules[tile_type]
			
			# Check each direction
			var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			
			for i in range(4):
				var nx = cx + directions[i].x
				var ny = cy + directions[i].y
				
				if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height and not collapsed_cells[nx][ny]:
					var allowed_neighbors = rules[i]
					var old_possibilities = cell_possibilities[nx][ny].duplicate()
					
					# Filter possibilities based on adjacency rules
					var new_possibilities = []
					for neighbor_type in cell_possibilities[nx][ny]:
						if neighbor_type in allowed_neighbors or allowed_neighbors.is_empty():
							new_possibilities.append(neighbor_type)
					
					cell_possibilities[nx][ny] = new_possibilities
					
					# If possibilities changed, add to queue for further propagation
					if cell_possibilities[nx][ny] != old_possibilities:
						queue.append(Vector2i(nx, ny))

func is_fully_collapsed() -> bool:
	for x in range(map_width):
		for y in range(map_height):
			if not collapsed_cells[x][y]:
				return false
	return true

func place_final_tiles():
	for x in range(map_width):
		for y in range(map_height):
			if collapsed_cells[x][y] and cell_possibilities[x][y].size() > 0:
				var tile_type = cell_possibilities[x][y][0]
				if tile_type != TileType.EMPTY and tiles[tile_type].size() > 0:
					var tile_id = tiles[tile_type][0]  # Use first available tile of this type
					road_layer.set_cell(Vector2i(x, y), tile_id, Vector2i(0, 0))
