extends Node
class_name GridManager

@onready var grid_map = $GridMap
@onready var player = $Player

func _ready():
	if grid_map:
		# Initialize pathfinding
		if grid_map.has_method("initialize_astar"):
			grid_map.initialize_astar()
		
		# Initialize 3x3 mode if enabled
		if grid_map.is_3x3_mode:
			detect_3x3_structures()
			print("Detected ", grid_map.three_by_three_centers.size(), " 3x3 structures")
			
			if not grid_map.three_by_three_centers.is_empty():
				var start_pos = grid_map.three_by_three_centers[0]
				player.current_position = start_pos
				player.global_position = grid_map.map_to_local(Vector3i(start_pos.x, 0, start_pos.y))
				print("Player positioned at 3x3 center: ", start_pos)
		
		print("Grid ready with pathfinding")
	else:
		print("Error: GridMap not found!")

func detect_3x3_structures():
	grid_map.three_by_three_centers.clear()
	
	# Check each possible center position
	for x in range(1, grid_map.columns - 1):
		for z in range(1, grid_map.rows - 1):
			if is_valid_3x3_center(x, z):
				grid_map.three_by_three_centers.append(Vector2i(x, z))
	
	print("3x3 centers detected: ", grid_map.three_by_three_centers)

func is_valid_3x3_center(center_x: int, center_z: int) -> bool:
	# Check all 9 cells in the 3x3 area
	for x_offset in range(-1, 2):
		for z_offset in range(-1, 2):
			var check_pos = Vector3i(center_x + x_offset, 0, center_z + z_offset)
			var item = grid_map.get_cell_item(check_pos)
			if item == -1:  # Empty cell
				return false
			if grid_map.non_walkable_items.has(item):  # Non-walkable item
				return false
	return true
