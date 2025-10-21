extends Node3D

@export var grid_map_path: NodePath
@export var is_3x3_mode: bool = false
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3.ZERO
@export var movement_speed: float = 0.3  # Time to move one cell

var grid_map: GridMap
var current_position: Vector2i
var is_moving: bool = false
var current_path: Array[Vector2i] = []
var path_index: int = 0

func _ready():
	grid_map = get_node_or_null(grid_map_path)
	if not grid_map:
		push_error("GridMap not found.")
		return
	
	await get_tree().process_frame
	
	current_position = Vector2i(2, 2)
	position = grid_to_world(current_position)
	global_position = position
	
	print("Player initialized at: ", current_position)

func _unhandled_input(event):
	if is_moving or not grid_map:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		if not camera:
			return
			
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		var clicked_grid_pos = raycast_to_grid(from, to)

		if clicked_grid_pos != Vector2i(-1, -1):
			start_movement_to(clicked_grid_pos)

func start_movement_to(target_pos: Vector2i):
	#"""Start moving to target position using pathfinding"""
	if not grid_map:
		return
	
	# Check if target is valid
	if target_pos.x < 0 or target_pos.x >= grid_map.columns or target_pos.y < 0 or target_pos.y >= grid_map.rows:
		print("Target outside grid bounds")
		return
	
	var cell_item = grid_map.get_cell_item(Vector3i(target_pos.x, 0, target_pos.y))
	if cell_item == -1 or grid_map.non_walkable_items.has(cell_item):
		print("Target not walkable")
		return
	
	# Find path to target
	var path = []
	if grid_map.has_method("find_path"):
		path = grid_map.find_path(current_position, target_pos)
	else:
		# Fallback: direct path
		path = [current_position, target_pos]
	
	if path.size() <= 1:
		print("Already at target or no path found")
		return
	
	print("Path found with ", path.size(), " steps: ", path)
	
	# Start following the path
	current_path = path
	path_index = 0
	move_to_next_step()

func move_to_next_step():
	#"""Move to the next step in the path"""
	if path_index >= current_path.size() - 1:
		# Reached the end of the path
		current_path.clear()
		path_index = 0
		is_moving = false
		print("Reached destination")
		return
	
	path_index += 1
	var next_pos = current_path[path_index]
	
	is_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var world_pos = grid_to_world(next_pos)
	tween.tween_property(self, "position", world_pos, movement_speed)
	
	await tween.finished
	current_position = next_pos
	is_moving = false
	
	print("Moved to step ", path_index, "/", current_path.size() - 1, ": ", current_position)
	
	# Continue to next step
	if path_index < current_path.size() - 1:
		move_to_next_step()

func raycast_to_grid(from: Vector3, to: Vector3) -> Vector2i:
	if not grid_map:
		return Vector2i(-1, -1)
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result:
		var grid_coords = grid_map.local_to_map(result.position)
		var grid_pos = Vector2i(grid_coords.x, grid_coords.z)
		
		if grid_pos.x < 0 or grid_pos.x >= grid_map.columns or grid_pos.y < 0 or grid_pos.y >= grid_map.rows:
			return Vector2i(-1, -1)
		
		var cell_item = grid_map.get_cell_item(Vector3i(grid_pos.x, 0, grid_pos.y))
		if cell_item == -1 or grid_map.non_walkable_items.has(cell_item):
			return Vector2i(-1, -1)
		
		return grid_pos
		
	return Vector2i(-1, -1)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	if not grid_map:
		return Vector3.ZERO
	
	var base_offset = Vector3(1.0, 0.0, 1.0)
	var world_pos = Vector3(
		base_offset.x + grid_pos.x * 2.0,
		0.0,
		base_offset.z + grid_pos.y * 2.0
	)
	
	return world_pos + cell_offset
