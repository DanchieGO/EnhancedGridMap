extends Node3D

@export var enhanced_gridmap_path: NodePath
@export var player_path: NodePath

var enhanced_gridmap: EnhancedGridMap
var player: Node3D
var current_position: Vector2i
var is_player_moving: bool = false
@export var is_3x3_mode: bool = true

# Customizable cell size and offset
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3(0, 0, 0)

# Diagonal movement flag
@export var use_diagonal_movement: bool = true:
	set(value):
		use_diagonal_movement = value
		if enhanced_gridmap:
			enhanced_gridmap.set_diagonal_movement(value)

# 3x3 mode settings
@export var force_3x3_mode: bool = true
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

	enhanced_gridmap.initialize_astar()
	enhanced_gridmap.set_diagonal_movement(use_diagonal_movement)

	# Force-create 3x3 structures at expected positions
	var required_centers = [Vector2i(2,2), Vector2i(6,2), Vector2i(2,6), Vector2i(6,6)]
	for center in required_centers:
		if enhanced_gridmap.is_valid_3x3_placement(center, 0):
			enhanced_gridmap.place_3x3_structure(center, "default", 0)
			if not enhanced_gridmap.three_by_three_centers.has(center):
				enhanced_gridmap.three_by_three_centers.append(center)
				print("Forced 3x3 structure at: ", center)
		else:
			print("Cannot force 3x3 structure at: ", center, " - invalid placement")

	current_position = find_valid_starting_position()
	update_player_position(current_position)

	# Detect and register 3x3 structure centers
	var centers = []
	for x in range(enhanced_gridmap.columns):
		for y in range(enhanced_gridmap.rows):
			var pos = Vector2i(x, y)
			if enhanced_gridmap.is_3x3_structure_center(pos):
				centers.append(pos)
				print("Detected 3x3 center at: ", pos)
	
	if centers.is_empty():
		push_warning("No 3x3 centers detected. Creating default center at (2,2).")
		enhanced_gridmap.place_3x3_structure(Vector2i(2, 2), "default", 0)
		enhanced_gridmap.three_by_three_centers.append(Vector2i(2, 2))
		centers.append(Vector2i(2, 2))
	
	enhanced_gridmap.initialize_astar()
	enhanced_gridmap.debug_grid_state()  # Debug grid state
	
	print("Player initialized at position: ", current_position)
	print("3x3 Mode: ", is_3x3_mode_active())
	print("Available 3x3 centers: ", enhanced_gridmap.three_by_three_centers)

func find_valid_starting_position() -> Vector2i:
	var start_pos = Vector2i(2, 2)
	var current_floor = 0

	if is_3x3_mode_active() and not enhanced_gridmap.is_3x3_structure_center(start_pos):
		push_warning("Starting position ", start_pos, " is not a valid 3x3 structure center. Attempting to place one.")
		if enhanced_gridmap.is_valid_3x3_placement(start_pos, 0):
			enhanced_gridmap.place_3x3_structure(start_pos, "default", 0)
			enhanced_gridmap.three_by_three_centers.append(start_pos)
		else:
			push_error("Failed to place 3x3 structure at ", start_pos)
	elif not is_3x3_mode_active() and not enhanced_gridmap.is_cell_walkable(start_pos, current_floor):
		push_warning("Starting position ", start_pos, " is not a walkable cell.")
	
	return start_pos

func _unhandled_input(event):
	if is_player_moving:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if enhanced_gridmap:
			enhanced_gridmap.is_3x3_mode = not enhanced_gridmap.is_3x3_mode
			print("3x3 Mode: ", "ON" if enhanced_gridmap.is_3x3_mode else "OFF")
			_handle_mode_change()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		create_test_3x3_structure()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		remove_3x3_structure_at_cursor()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		var click_position = raycast_to_grid(from, to)
		if click_position != Vector2i(-1, -1):
			print("Clicked position: ", click_position)
			move_player_to_clicked_position(click_position)

func _handle_mode_change():
	if is_3x3_mode_active():
		if not is_valid_position_for_current_mode(current_position):
			var valid_pos = enhanced_gridmap.three_by_three_centers[0] if enhanced_gridmap.three_by_three_centers else Vector2i(2, 2)
			push_warning("Current position invalid for 3x3 mode, reverting to ", valid_pos)
			current_position = valid_pos
			update_player_position(current_position)
			print("Moved player to: ", current_position)
	else:
		if not enhanced_gridmap.is_cell_walkable(current_position, 0):
			var valid_pos = Vector2i(2, 2)
			push_warning("Current position invalid for normal mode, reverting to ", valid_pos)
			current_position = valid_pos
			update_player_position(current_position)
			print("Moved player to: ", current_position)

func is_valid_position_for_current_mode(pos: Vector2i) -> bool:
	if is_3x3_mode_active():
		var is_valid = enhanced_gridmap.is_3x3_structure_center(pos)
		print("Checking if ", pos, " is valid 3x3 center: ", is_valid)
		return is_valid
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

func is_direct_3x3_neighbor(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	var is_neighbor = (dx == 4 and dy == 0) or (dx == 0 and dy == 4) or (dx == 4 and dy == 4)
	print("Checking if ", pos2, " is direct 3x3 neighbor of ", pos1, ": ", is_neighbor)
	return is_neighbor

func move_player_to_clicked_position(grid_position: Vector2i):
	if not is_valid_target_position(grid_position):
		print("Invalid target position for current mode: ", grid_position)
		show_invalid_move_feedback(grid_position)
		return
	
	var path: Array
	
	if is_3x3_mode_active():
		var is_neighbor = is_direct_3x3_neighbor(current_position, grid_position)
		var is_clear = enhanced_gridmap.is_clear_line_of_sight(current_position, grid_position, 0)
		print("Move check - Neighbor: ", is_neighbor, ", Clear LOS: ", is_clear, " for target: ", grid_position)
		if is_neighbor and is_clear:
			path = [Vector2(current_position), Vector2(grid_position)]
		else:
			print("Not a direct neighbor or path blocked: ", grid_position)
			show_invalid_move_feedback(grid_position)
			return
	else:
		path = enhanced_gridmap.find_path(Vector2(current_position), Vector2(grid_position))
	
	if path.size() > 1:
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
	
	enhanced_gridmap.clear_path_visualization()
	
	var move_duration = 0.5
	for i in range(path.size()):
		var point = path[i]
		var target_position = grid_to_world(Vector2i(point.x, point.y))
		
		if is_3x3_mode_active() or enhanced_gridmap.is_3x3_structure_center(Vector2i(point.x, point.y)):
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
	
	var feedback_item = enhanced_gridmap.non_walkable_items[0] if not enhanced_gridmap.non_walkable_items.is_empty() else 4
	var original_item = enhanced_gridmap.get_cell_item(Vector3i(pos.x, 0, pos.y))
	
	enhanced_gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y), feedback_item)
	
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		enhanced_gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y), original_item)
	)

func is_valid_target_position(pos: Vector2i) -> bool:
	if is_3x3_mode_active():
		var is_valid = enhanced_gridmap.is_3x3_structure_center(pos)
		print("Checking if ", pos, " is valid 3x3 target: ", is_valid)
		return is_valid
	else:
		return enhanced_gridmap.is_cell_walkable(pos, 0)

func create_test_3x3_structure():
	if not enhanced_gridmap:
		return
	
	var test_positions = [
		current_position + Vector2i(4, 0),
		current_position + Vector2i(-4, 0),
		current_position + Vector2i(0, 4),
		current_position + Vector2i(0, -4),
		current_position + Vector2i(4, 4),
		current_position + Vector2i(-4, -4),
		current_position + Vector2i(4, -4),
		current_position + Vector2i(-4, 4)
	]
	
	for pos in test_positions:
		if enhanced_gridmap.is_valid_3x3_placement(pos, 0):
			enhanced_gridmap.place_3x3_structure(pos, "default", 0)
			enhanced_gridmap.three_by_three_centers.append(pos)
			enhanced_gridmap.initialize_astar()
			print("Created test 3x3 structure at: ", pos)
			return
	
	print("Could not find valid position for test 3x3 structure")

func remove_3x3_structure_at_cursor():
	if not enhanced_gridmap:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var grid_pos = raycast_to_grid(from, to)
	if grid_pos != Vector2i(-1, -1):
		var structure_center = enhanced_gridmap.get_3x3_structure_center(grid_pos)
		if structure_center != Vector2i(-1, -1):
			enhanced_gridmap.remove_3x3_structure(structure_center, 0)
			enhanced_gridmap.three_by_three_centers.erase(structure_center)
			enhanced_gridmap.initialize_astar()
			print("Removed 3x3 structure at center: ", structure_center)
		else:
			print("No 3x3 structure found at: ", grid_pos)

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
		var directions = [
			Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 0), Vector2i(-4, 0),
			Vector2i(4, 4), Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4)
		]
		for dir in directions:
			var target_pos = current_position + dir
			if enhanced_gridmap.is_position_valid(target_pos) and \
			   enhanced_gridmap.is_3x3_structure_center(target_pos) and \
			   enhanced_gridmap.is_clear_line_of_sight(current_position, target_pos, 0):
				available.append(target_pos)
				print("Valid move to: ", target_pos)
	else:
		var directions = [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
		]
		
		if use_diagonal_movement:
			directions.append_array([
				Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
			])
		
		for dir in directions:
			var check_pos = current_position + dir
			if enhanced_gridmap.is_position_valid(check_pos) and enhanced_gridmap.is_cell_walkable(check_pos, 0):
				available.append(check_pos)
	
	return available

func is_valid_jump_connection(c1: Vector2i, c2: Vector2i) -> bool:
	var dx = abs(c2.x - c1.x)
	var dy = abs(c2.y - c1.y)
	var is_valid = (dx == 4 and dy == 0) or (dx == 0 and dy == 4) or (dx == 4 and dy == 4)
	print("Checking jump connection from ", c1, " to ", c2, ": ", is_valid)
	return is_valid
