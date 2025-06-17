extends Node3D

@export var enhanced_gridmap_path: NodePath
@export var player_path: NodePath

var enhanced_gridmap: EnhancedGridMap
var player: Node3D
var current_position: Vector2i
var is_player_moving: bool = false

# Customizable cell size and offset
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3(0, 0, 0)

# Center offset flags
@export var center_x: bool = false
@export var center_y: bool = false
@export var center_z: bool = false

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

	# Ensure the A* graph is initialized
	enhanced_gridmap.initialize_astar()
	
	# Sync diagonal movement setting with the plugin
	enhanced_gridmap.set_diagonal_movement(use_diagonal_movement)

	# Position the player at a valid starting position
	#current_position = find_valid_starting_position()
	current_position = Vector2i(0,2)
	update_player_position(current_position)

func find_valid_starting_position() -> Vector2i:
	for x in range(enhanced_gridmap.columns):
		for z in range(enhanced_gridmap.rows):
			for item in enhanced_gridmap.non_walkable_items.size():
				if enhanced_gridmap.get_cell_item(Vector3i(x, 0, z)) != enhanced_gridmap.non_walkable_items[item]:
					return Vector2i(x, z)
	return Vector2i(0, 0)  # Fallback to (0,0) if no valid position found

func _unhandled_input(event):
	
	if is_player_moving:
		return  # Ignore input if the player is already moving

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
	var cell_item = enhanced_gridmap.get_cell_item(Vector3i(grid_position.x, 0, grid_position.y))
	
	for x in enhanced_gridmap.non_walkable_items.size():
		if cell_item == enhanced_gridmap.non_walkable_items[x]:
			print("Cannot move to non-walkable cell")
			return
	
	var path = enhanced_gridmap.find_path(Vector2(current_position), Vector2(grid_position))
	
	if path.size() > 1:
		path.pop_front()
		move_player_along_path(path)
	else:
		print("No valid path found")

func move_player_along_path(path: Array):
	is_player_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Visualize the path using the plugin's function
	#enhanced_gridmap.visualize_path(path)
	
	for point in path:
		var target_position = grid_to_world(Vector2i(point.x, point.y))
		tween.tween_property(player, "position", target_position, 0.5)
	
	tween.tween_callback(func():
		current_position = Vector2i(path[-1].x, path[-1].y)
		is_player_moving = false
		enhanced_gridmap.clear_path_visualization()
	)

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
	
	# Apply additional center offsets if needed
	if center_x:
		world_position.x += cell_size.x * 0.5
	if center_y:
		world_position.y += cell_size.y * 0.5
	if center_z:
		world_position.z += cell_size.z * 0.5
	
	return world_position + cell_offset
