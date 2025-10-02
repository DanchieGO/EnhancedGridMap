extends Node3D

@export var enhanced_gridmap_path: NodePath
@export var player_path: NodePath

var enhanced_gridmap: EnhancedGridMap
var player: Node3D
var current_position: Vector2i
var is_player_moving: bool = false
@export var is_3x3_mode: bool = false

# Customizable cell size and offset
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3(0, 0, 0)

# Diagonal movement flag
@export var use_diagonal_movement: bool = false:
	set(value):
		use_diagonal_movement = value
		if enhanced_gridmap:
			enhanced_gridmap.set_diagonal_movement(value)

# 3x3 mode settings
@export var force_3x3_mode: bool = false  # Override gridmap's 3x3 mode setting
@export var visual_feedback_enabled: bool = true
@export var invalid_move_color: Color = Color.RED
@export var valid_move_color: Color = Color.GREEN

func is_3x3_mode_active() -> bool:
	return force_3x3_mode or (enhanced_gridmap and enhanced_gridmap.is_3x3_mode)

func _ready():
	enhanced_gridmap = get_node(enhanced_gridmap_path)
	player = get_node(player_path)

	if not enhanced_gridmap or not player:
		push_error("EnhancedGridMap or Player node not found. Please set the correct paths in the inspector.")
		return

	# Ensure the A* graph is initialized with 3x3 support
	enhanced_gridmap.initialize_astar()
	
	# Sync diagonal movement setting with the plugin
	enhanced_gridmap.set_diagonal_movement(use_diagonal_movement)

	# Position the player at the specified starting position
	current_position = find_valid_starting_position()
	update_player_position(current_position)
	
	print("Player initialized at position: ", current_position)
	print("3x3 Mode: ", is_3x3_mode_active())

func find_valid_starting_position() -> Vector2i:
	var current_floor = 0  # Assuming floor 0 for simplicity
	var start_pos = Vector2i(2, 2)  # Maps to grid (2,0,2) in 3D coordinates

	# Validate the position for the current mode
	if is_3x3_mode_active() and not enhanced_gridmap.is_3x3_structure_center(start_pos):
		push_warning("Starting position ", start_pos, " is not a valid 3x3 structure center.")
	elif not is_3x3_mode_active() and not enhanced_gridmap.is_cell_walkable(start_pos, current_floor):
		push_warning("Starting position ", start_pos, " is not a walkable cell.")
	
	return start_pos

func _unhandled_input(event):
	if is_player_moving:
		return  # Ignore input if the player is already moving

	# Toggle 3x3 mode with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if enhanced_gridmap:
			enhanced_gridmap.is_3x3_mode = not enhanced_gridmap.is_3x3_mode
			print("3x3 Mode: ", "ON" if enhanced_gridmap.is_3x3_mode else "OFF")
			_handle_mode_change()
		return
	
	# Create test 3x3 structure with C key
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		create_test_3x3_structure()
		return
	
	# Remove 3x3 structure with R key
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		remove_3x3_structure_at_cursor()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		
		var click_position = raycast_to_grid(from, to)
		if click_position != Vector2i(-1, -1):
			move_player_to_clicked_position(click_position)

func _handle_mode_change():
	# When switching modes, validate current player position
	if is_3x3_mode_active():
		# Switching to 3x3 mode
		if not is_valid_position_for_current_mode(current_position):
			var valid_pos = Vector2i(2, 2)  # Default to (2,0,2)
			push_warning("Current position invalid for 3x3 mode, reverting to ", valid_pos)
			current_position = valid_pos
			update_player_position(current_position)
			print("Moved player to: ", current_position)
	else:
		# Switching to normal mode
		if not enhanced_gridmap.is_cell_walkable(current_position, 0):
			var valid_pos = Vector2i(2, 2)  # Default to (2,0,2)
			push_warning("Current position invalid for normal mode, reverting to ", valid_pos)
			current_position = valid_pos
			update_player_position(current_position)
			print("Moved player to: ", current_position)

func is_valid_position_for_current_mode(pos: Vector2i) -> bool:
	if is_3x3_mode_active():
		return enhanced_gridmap.is_3x3_structure_center(pos)
	else:
		return enhanced_gridmap.is_cell_walkable(pos, 0)

func raycast_to_grid(from: Vector3, to: Vector3) -> Vector2i:
	var plane = Plane(Vector3.UP, cell_offset.y)
	var intersection = plane.intersects_ray(from, to - from)
	
	if intersection:
		var adjusted_intersection = intersection - cell_offset
		var grid_position = Vector2i(
			floor(adjusted_intersection.x / cell_size.x),
			floor(adjusted_intersection.z / cell_size.z)
		)
		
		if grid_position.x >= 0 and grid_position.x < enhanced_gridmap.columns and \
		   grid_position.y >= 0 and grid_position.y < enhanced_gridmap.rows:
			return grid_position
	
	return Vector2i(-1, -1)

func move_player_to_clicked_position(grid_position: Vector2i):
	# Validate the target position based on current mode
	if not is_valid_target_position(grid_position):
		print("Invalid target position for current mode: ", grid_position)
		show_invalid_move_feedback(grid_position)
		return
	
	var path: Array
	
	if is_3x3_mode_active():
		# Use 3x3 mode pathfinding
		path = enhanced_gridmap.find_path_3x3_mode(Vector2(current_position), Vector2(grid_position))
	else:
		# Use regular pathfinding
		path = enhanced_gridmap.find_path(Vector2(current_position), Vector2(grid_position))
	
	if path.size() > 1:
		# Remove the starting position from the path if it's the same
		if Vector2i(path[0]) == current_position:
			path.pop_front()
		move_player_along_path(path)
	else:
		print("No valid path found to: ", grid_position)
		show_invalid_move_feedback(grid_position)

func move_player_along_path(path: Array):
	is_player_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Clear any existing path visualization
	enhanced_gridmap.clear_path_visualization()
	
	# Visualize the path (skip final position)
	for i in range(path.size() - 1):
		var point = path[i]
		enhanced_gridmap.set_cell_item(Vector3i(point.x, 0, point.y), enhanced_gridmap.hover_item)
	
	var move_duration = 0.5
	for i in range(path.size()):
		var point = path[i]
		var target_position = grid_to_world(Vector2i(point.x, point.y))
		
		# Special handling for 3x3 structures
		if is_3x3_mode_active() or enhanced_gridmap.is_3x3_structure_center(Vector2i(point.x, point.y)):
			# Longer duration for 3x3 movement
			tween.tween_property(player, "position", target_position, move_duration * 1.2)
			print("Moving to 3x3 center at: ", point)
		else:
			tween.tween_property(player, "position", target_position, move_duration)
	
	tween.tween_callback(func():
		var final_pos = path[-1]
		current_position = Vector2i(final_pos.x, final_pos.y)
		is_player_moving = false
		enhanced_gridmap.clear_path_visualization()
		print("Player moved to: ", current_position, " (Mode: ", "3x3" if is_3x3_mode_active() else "Normal", ")")
	)

func show_invalid_move_feedback(pos: Vector2i):
	if not visual_feedback_enabled:
		return
	
	# Create temporary visual feedback for invalid moves
	var feedback_item = enhanced_gridmap.non_walkable_items[0] if not enhanced_gridmap.non_walkable_items.is_empty() else 4
	var original_item = enhanced_gridmap.get_cell_item(Vector3i(pos.x, 0, pos.y))
	
	# Flash the invalid cell
	enhanced_gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y), feedback_item)
	
	var feedback_tween = create_tween()
	feedback_tween.tween_interval(0.3)  # Fixed from tween_delay
	feedback_tween.tween_callback(func():
		enhanced_gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y), original_item)
	)

func is_valid_target_position(pos: Vector2i) -> bool:
	if is_3x3_mode_active():
		# In 3x3 mode, only allow movement to 3x3 structure centers
		return enhanced_gridmap.is_3x3_structure_center(pos)
	else:
		# In normal mode, allow movement to any walkable cell
		return enhanced_gridmap.is_cell_walkable(pos, 0)

func create_test_3x3_areas():
	# Create some test 3x3 blue areas
	enhanced_gridmap.create_3x3_blue_area(Vector2i(2, 2))  # Top-left 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(6, 2))  # Top-right 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(2, 6))  # Bottom-left 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(6, 6))  # Bottom-right 3x3
	print("Created test 3x3 areas")

func is_valid_3x3_area(center_pos: Vector2i) -> bool:
	# Check if all 9 cells in the 3x3 area are within bounds and walkable
	for x in range(-1, 2):  # -1, 0, 1
		for y in range(-1, 2):  # -1, 0, 1
			var check_pos = Vector2i(center_pos.x + x, center_pos.y + y)
			
			# Check if position is within grid bounds
			if check_pos.x < 0 or check_pos.x >= enhanced_gridmap.columns or \
			   check_pos.y < 0 or check_pos.y >= enhanced_gridmap.rows:
				return false
			
			# Check if cell is walkable
			var cell_item = enhanced_gridmap.get_cell_item(Vector3i(check_pos.x, 0, check_pos.y))
			for item in enhanced_gridmap.non_walkable_items:
				if cell_item == item:
					return false
	
	return true

func place_3x3_cells(center_pos: Vector2i):
	# Place blue cells in a 3x3 pattern
	for x in range(-1, 2):  # -1, 0, 1
		for y in range(-1, 2):  # -1, 0, 1
			var place_pos = Vector2i(center_pos.x + x, center_pos.y + y)
			enhanced_gridmap.set_cell_item(Vector3i(place_pos.x, 0, place_pos.y), 1)  # Assuming 1 is the blue cell item index
	
	# Update the player position to the center of the 3x3 area
	current_position = center_pos
	update_player_position(current_position)

func update_player_position(grid_position: Vector2i):
	player.position = grid_to_world(grid_position)

func grid_to_world(grid_position: Vector2i) -> Vector3:
	var world_position = Vector3(
		grid_position.x * cell_size.x,
		cell_size.y,  # Place the player on top of the cell
		grid_position.y * cell_size.z
	)
	
	# Center the player within the cell
	world_position.x += cell_size.x * 0.5
	world_position.z += cell_size.z * 0.5 
	
	return world_position + cell_offset

func create_test_3x3_structure():
	if not enhanced_gridmap:
		return
	
	# Find a valid position near the player to create a 3x3 structure
	var test_positions = [
		current_position + Vector2i(4, 0),
		current_position + Vector2i(-4, 0),
		current_position + Vector2i(0, 4),
		current_position + Vector2i(0, -4),
		current_position + Vector2i(3, 3),
		current_position + Vector2i(-3, -3)
	]
	
	for pos in test_positions:
		if enhanced_gridmap.is_valid_3x3_placement(pos, 0):
			enhanced_gridmap.place_3x3_structure(pos, "default", 0)
			print("Created test 3x3 structure at: ", pos)
			return
	
	print("Could not find valid position for test 3x3 structure")

func remove_3x3_structure_at_cursor():
	if not enhanced_gridmap:
		return
	
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var grid_pos = raycast_to_grid(from, to)
	if grid_pos != Vector2i(-1, -1):
		# Check if this position is part of a 3x3 structure
		var structure_center = enhanced_gridmap.get_3x3_structure_center(grid_pos)
		if structure_center != Vector2i(-1, -1):
			enhanced_gridmap.remove_3x3_structure(structure_center, 0)
			print("Removed 3x3 structure at center: ", structure_center)
		else:
			print("No 3x3 structure found at: ", grid_pos)

func print_current_mode_info():
	print("=== Player Mode Info ===")
	print("Current Position: ", current_position)
	print("3x3 Mode Active: ", is_3x3_mode_active())
	print("Force 3x3 Mode: ", force_3x3_mode)
	print("GridMap 3x3 Mode: ", enhanced_gridmap.is_3x3_mode if enhanced_gridmap else "N/A")
	print("Position Valid for Mode: ", is_valid_position_for_current_mode(current_position))
	if enhanced_gridmap:
		print("Available 3x3 Centers: ", enhanced_gridmap.three_by_three_centers)
	print("========================")

func get_available_moves() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	
	if is_3x3_mode_active():
		# Return all 3x3 centers that are reachable
		for center in enhanced_gridmap.three_by_three_centers:
			if center != current_position:
				var path = enhanced_gridmap.find_path_3x3_mode(Vector2(current_position), Vector2(center))
				if not path.is_empty():
					available.append(center)
	else:
		# Return all walkable adjacent cells
		var directions = [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)  # Cardinal
		]
		
		if use_diagonal_movement:
			directions.append_array([
				Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)  # Diagonal
			])
		
		for dir in directions:
			var check_pos = current_position + dir
			if enhanced_gridmap.is_position_valid(check_pos) and enhanced_gridmap.is_cell_walkable(check_pos, 0):
				available.append(check_pos)
	
	return available
