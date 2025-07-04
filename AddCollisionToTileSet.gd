@tool
extends EditorScript

func _run():
	var tileset = load("res://RoadTileSet.tres") as TileSet
	if not tileset:
		print("Failed to load TileSet!")
		return
	
	print("Adding collision shapes to TileSet...")
	
	# Add collision shapes for each tile source
	for source_id in tileset.get_source_count():
		var source = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			
			# Add collision shapes for each tile in the atlas source
			for i in range(atlas_source.get_tiles_count()):
				var atlas_coords = atlas_source.get_tile_id(i)
				
				# Create collision shape for this tile
				var collision_shape = RectangleShape2D.new()
				collision_shape.size = Vector2(64, 64)  # Match tile size
				
				# Add physics layer if it doesn't exist
				if tileset.get_physics_layers_count() == 0:
					tileset.add_physics_layer()
				
				# Add collision polygon to the tile
				atlas_source.set_tile_physics_layer_polygon_count(atlas_coords, 0, 0, 1)
				
				# Create a rectangle polygon for the road boundaries
				var road_polygon = create_road_boundary_polygon(atlas_source.texture, atlas_coords)
				atlas_source.set_tile_physics_layer_polygon_polygon(atlas_coords, 0, 0, 0, road_polygon)
	
	# Save the modified tileset
	ResourceSaver.save(tileset, "res://RoadTileSet.tres")
	print("Collision shapes added to TileSet!")

func create_road_boundary_polygon(texture: Texture2D, atlas_coords: Vector2i) -> PackedVector2Array:
	# Create a boundary polygon that blocks movement outside the road
	# This creates invisible walls around the road edges
	
	var polygon = PackedVector2Array()
	var tile_size = 64
	var road_width = 40  # Width of the driveable road area
	var margin = (tile_size - road_width) / 2
	
	# Create boundaries around the road area
	# Top boundary
	polygon.append(Vector2(0, 0))
	polygon.append(Vector2(tile_size, 0))
	polygon.append(Vector2(tile_size, margin))
	polygon.append(Vector2(0, margin))
	
	# Bottom boundary  
	polygon.append(Vector2(0, tile_size - margin))
	polygon.append(Vector2(tile_size, tile_size - margin))
	polygon.append(Vector2(tile_size, tile_size))
	polygon.append(Vector2(0, tile_size))
	
	# Left boundary
	polygon.append(Vector2(0, margin))
	polygon.append(Vector2(margin, margin))
	polygon.append(Vector2(margin, tile_size - margin))
	polygon.append(Vector2(0, tile_size - margin))
	
	# Right boundary
	polygon.append(Vector2(tile_size - margin, margin))
	polygon.append(Vector2(tile_size, margin))
	polygon.append(Vector2(tile_size, tile_size - margin))
	polygon.append(Vector2(tile_size - margin, tile_size - margin))
	
	return polygon