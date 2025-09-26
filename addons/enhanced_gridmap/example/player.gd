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

	# Position the player at a valid starting position
	current_position = Vector2i(4, 4)  # Start in the middle
	update_player_position(current_position)
	
	# Create test 3x3 areas (comment this out in production)
	create_test_3x3_areas()

func find_valid_starting_position() -> Vector2i:
	for x in range(enhanced_gridmap.columns):
		for z in range(enhanced_gridmap.rows):
			for item in enhanced_gridmap.non_walkable_items.size():
				if enhanced_gridmap.get_cell_item(Vector3i(x, 0, z)) != enhanced_gridmap.non_walkable_items[item]:
					return Vector2i(x, z)
	return Vector2i(2, 2)  # Fallback to (0,0) if no valid position found

#func _unhandled_input(event):
	#
	#if is_player_moving:
		#return  # Ignore input if the player is already moving
#
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#var camera = get_viewport().get_camera_3d()
		#var from = camera.project_ray_origin(event.position)
		#var to = from + camera.project_ray_normal(event.position) * 1000
		#
		#var click_position = raycast_to_grid(from, to)
		#if click_position != Vector2i(-1, -1):
			#move_player_to_clicked_position(click_position)

func _unhandled_input(event):
	if is_player_moving:
		return  # Ignore input if the player is already moving

	# Toggle 3x3 mode with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		is_3x3_mode = not is_3x3_mode
		print("3x3 Mode: ", "ON" if is_3x3_mode else "OFF")
		return
	
	# Create test areas with C key
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		create_test_3x3_areas()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		
		var click_position = raycast_to_grid(from, to)
		if click_position != Vector2i(-1, -1):
			move_player_to_clicked_position(click_position)

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
	if is_3x3_mode:
		# Check if the 3x3 area is valid
		if is_valid_3x3_area(grid_position):
			place_3x3_cells(grid_position)
		else:
			print("Cannot place 3x3 cells at this position")
		return
	
	# Enhanced pathfinding with 3x3 jump support
	var path = enhanced_gridmap.find_path_with_3x3_jump(Vector2(current_position), Vector2(grid_position))
	
	if path.size() > 1:
		# Remove the starting position from the path
		if path[0] == Vector2(current_position):
			path.pop_front()
		move_player_along_path(path)
	else:
		print("No valid path found")

# Enhanced path movement that handles smooth transitions into 3x3 areas
#func move_player_along_path(path: Array):
	#is_player_moving = true
	#var tween = create_tween()
	#tween.set_trans(Tween.TRANS_CUBIC)
	#tween.set_ease(Tween.EASE_IN_OUT)
	#
	## Clear any existing path visualization
	#enhanced_gridmap.clear_path_visualization()
	#
	## Visualize the path
	#for i in range(path.size() - 1):  # Don't visualize the final position
		#var point = path[i]
		#enhanced_gridmap.set_cell_item(Vector3i(point.x, 0, point.y), enhanced_gridmap.hover_item)
	#
	#var move_duration = 0.5
	#for i in range(path.size()):
		#var point = path[i]
		#var target_position = grid_to_world(Vector2i(point.x, point.y))
		#
		## Check if this point is a 3x3 center for special handling
		#if enhanced_gridmap.is_3x3_center(Vector2i(point.x, point.y)):
			#print("Moving to 3x3 center at: ", point)
			## Slightly longer duration for jumping into 3x3 areas
			#tween.tween_property(player, "position", target_position, move_duration * 1.2)
		#else:
			#tween.tween_property(player, "position", target_position, move_duration)
	#
	#tween.tween_callback(func():
		#var final_pos = path[-1]
		#current_position = Vector2i(final_pos.x, final_pos.y)
		#is_player_moving = false
		#enhanced_gridmap.clear_path_visualization()
		#print("Player moved to: ", current_position)
	#)

# Enhanced path movement that handles smooth transitions into 3x3 areas
func move_player_along_path(path: Array):
	is_player_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Clear any existing path visualization
	enhanced_gridmap.clear_path_visualization()
	
	# Visualize the path
	for i in range(path.size() - 1):  # Don't visualize the final position
		var point = path[i]
		enhanced_gridmap.set_cell_item(Vector3i(point.x, 0, point.y), enhanced_gridmap.hover_item)
	
	var move_duration = 0.5
	for i in range(path.size()):
		var point = path[i]
		var target_position = grid_to_world(Vector2i(point.x, point.y))
		
		# Check if this point is a 3x3 center for special handling
		if enhanced_gridmap.is_3x3_center(Vector2i(point.x, point.y)):
			print("Moving to 3x3 center at: ", point)
			# Slightly longer duration for jumping into 3x3 areas
			tween.tween_property(player, "position", target_position, move_duration * 1.2)
		else:
			tween.tween_property(player, "position", target_position, move_duration)
	
	tween.tween_callback(func():
		var final_pos = path[-1]
		current_position = Vector2i(final_pos.x, final_pos.y)
		is_player_moving = false
		enhanced_gridmap.clear_path_visualization()
		print("Player moved to: ", current_position)
	)

# Add a helper function to create test 3x3 areas
func create_test_3x3_areas():
	# Create some test 3x3 blue areas
	enhanced_gridmap.create_3x3_blue_area(Vector2i(2, 2))  # Top-left 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(6, 2))  # Top-right 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(2, 6))  # Bottom-left 3x3
	enhanced_gridmap.create_3x3_blue_area(Vector2i(6, 6))  # Bottom-right 3x3
	print("Created test 3x3 areas")

# Add these new functions
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
