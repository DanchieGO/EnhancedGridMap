# player.gd
extends Node3D

@export var grid_manager_path: NodePath
@export var is_3x3_mode: bool = true
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3.ZERO

var grid_manager: GridManager
var current_position: Vector2i
var is_moving: bool = false

func _ready():
	grid_manager = get_node_or_null(grid_manager_path)
	if not grid_manager:
		push_error("GridManager node not found. Please set the correct path.")
		return

	# Find a valid starting position
	if is_3x3_mode:
		if not grid_manager.three_by_three_centers.is_empty():
			current_position = grid_manager.three_by_three_centers[0]
		else:
			push_warning("No 3x3 centers detected. Starting at (2,2).")
			current_position = Vector2i(2, 2)
	else:
		current_position = Vector2i(grid_manager.columns / 2, grid_manager.rows / 2)
	
	position = grid_to_world(current_position)
	
	# Connect to the grid_updated signal to re-evaluate position if grid changes
	grid_manager.grid_updated.connect(_on_grid_updated)

func _unhandled_input(event):
	if is_moving:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		var clicked_grid_pos = raycast_to_grid(from, to)

		if clicked_grid_pos != Vector2i(-1, -1):
			handle_move_request(clicked_grid_pos)

func handle_move_request(target_pos: Vector2i):
	var path: Array

	if is_3x3_mode:
		if grid_manager.is_3x3_structure_center(target_pos):
			# In 3x3 mode, we check for direct adjacency or clear line of sight
			if is_direct_3x3_neighbor(current_position, target_pos) and grid_manager.is_clear_line_of_sight(current_position, target_pos, 0):
				path = [Vector2(current_position), Vector2(target_pos)]
			else:
				print("Target is not a direct or clear neighbor in 3x3 mode.")
				return
		else:
			print("Invalid target: Not a 3x3 center.")
			return
	else:
		# Standard pathfinding
		path = grid_manager.find_path(Vector2(current_position), Vector2(target_pos))

	if not path.is_empty():
		move_along_path(path)

func move_along_path(path: Array):
	is_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for point in path:
		var world_pos = grid_to_world(Vector2i(point))
		tween.tween_property(self, "position", world_pos, 0.4)
	
	await tween.finished
	var final_pos = path[-1]
	current_position = Vector2i(final_pos)
	is_moving = false

# --- Utility Functions ---

func _on_grid_updated():
	# If the grid changes, ensure the player is on a valid tile
	if is_3x3_mode and not grid_manager.is_3x3_structure_center(current_position):
		if not grid_manager.three_by_three_centers.is_empty():
			current_position = grid_manager.three_by_three_centers[0]
			position = grid_to_world(current_position)
			
func is_direct_3x3_neighbor(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	# Assuming 3x3 structures are on a 4x4 grid spacing
	return (dx == 4 and dy == 0) or (dx == 0 and dy == 4) or (dx == 4 and dy == 4)

func raycast_to_grid(from: Vector3, to: Vector3) -> Vector2i:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result:
		var grid_coords = grid_manager.local_to_map(result.position)
		return Vector2i(grid_coords.x, grid_coords.z)
		
	return Vector2i(-1, -1)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_pos = grid_manager.map_to_local(Vector3i(grid_pos.x, 0, grid_pos.y))
	# Adjust for cell size to place player in the center
	world_pos += Vector3(cell_size.x / 2.0, 0, cell_size.z / 2.0)
	return world_pos + cell_offset
