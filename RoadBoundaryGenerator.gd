extends Node2D

@export var road_width: float = 40.0
@export var tile_size: float = 64.0

var road_grid: Array[Array] = []
var map_width: int = 30
var map_height: int = 30

func _ready():
	if has_method("generate_road_boundaries"):
		call_deferred("generate_road_boundaries")

func generate_road_boundaries():
	# Get the map generator to access road grid data
	var map_generator = get_parent().get_node("MapGenerator")
	if not map_generator:
		print("MapGenerator not found!")
		return
	
	if not map_generator.has_method("get_road_grid"):
		print("MapGenerator doesn't have get_road_grid method!")
		return
	
	road_grid = map_generator.get_road_grid()
	map_width = map_generator.map_width
	map_height = map_generator.map_height
	
	print("Generating road boundaries...")
	
	# Clear existing boundaries
	for child in get_children():
		child.queue_free()
	
	# Create boundary walls around non-road areas
	create_boundary_walls()
	
	print("Road boundaries generated!")

func create_boundary_walls():
	# Create static body collision shapes around the edges of roads
	# This prevents vehicles from driving into non-road areas
	
	for x in range(map_width):
		for y in range(map_height):
			if is_road_tile(x, y):
				continue  # Skip road tiles
			
			# Create a wall tile for non-road areas
			var wall_body = StaticBody2D.new()
			wall_body.name = "Wall_" + str(x) + "_" + str(y)
			wall_body.position = Vector2(x * tile_size + tile_size/2, y * tile_size + tile_size/2)
			
			# Add collision shape
			var collision_shape = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(tile_size, tile_size)
			collision_shape.shape = shape
			
			# Set collision layer for walls
			wall_body.collision_layer = 1  # Layer 1 for walls
			wall_body.collision_mask = 0   # Walls don't need to detect anything
			
			wall_body.add_child(collision_shape)
			add_child(wall_body)
			
			# Optional: Add visual indicator for walls (for debugging)
			if false:  # Set to true to see wall boundaries
				var wall_sprite = ColorRect.new()
				wall_sprite.color = Color(0.5, 0.5, 0.5, 0.3)
				wall_sprite.size = Vector2(tile_size, tile_size)
				wall_sprite.position = Vector2(-tile_size/2, -tile_size/2)
				wall_body.add_child(wall_sprite)

func is_road_tile(x: int, y: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return false
	
	if road_grid.size() <= x or road_grid[x].size() <= y:
		return false
	
	# Check if this is a road tile (not empty)
	return road_grid[x][y] != 0  # 0 represents empty/non-road
