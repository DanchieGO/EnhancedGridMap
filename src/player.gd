extends Node3D

@export var grid_map_path: NodePath  # Direct path to GridMap node
@export var is_3x3_mode: bool = true
@export var cell_size: Vector3 = Vector3(2, 2, 2)
@export var cell_offset: Vector3 = Vector3.ZERO

var grid_map: GridMap
var current_position: Vector2i
var is_moving: bool = false

func _ready():
	# Get direct reference to GridMap
	grid_map = get_node_or_null(grid_map_path)
	if not grid_map:
		push_error("GridMap not found. Please set the correct grid_map_path.")
		return
	
	# Wait for complete initialization
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set exact starting position
	current_position = Vector2i(2, 2)
	position = Vector3(5.0, 0.0, 5.0)
	global_position = Vector3(5.0, 0.0, 5.0)  # Ensure global position is set
	
	print("Player initialized at grid: ", current_position, " world: ", position)
	print("GridMap cell_size: ", grid_map.cell_size)

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
			handle_move_request(clicked_grid_pos)

func handle_move_request(target_pos: Vector2i):
	if not grid_map:
		return
		
	# In 3x3 mode, check if target is a valid 3x3 center
	if is_3x3_mode and grid_map.has_method("detect_3x3_structures"):
		if target_pos in grid_map.three_by_three_centers:
			move_to_position(target_pos)
		else:
			print("Invalid target: Not a 3x3 center.")
	else:
		# Normal mode - check if walkable
		var item = grid_map.get_cell_item(Vector3i(target_pos.x, 0, target_pos.y))
		if item != -1 and not grid_map.non_walkable_items.has(item):
			move_to_position(target_pos)
		else:
			print("Invalid target: Cell is not walkable.")

func move_to_position(target_pos: Vector2i):
	if not grid_map:
		return
		
	is_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var world_pos = grid_to_world(target_pos)
	tween.tween_property(self, "position", world_pos, 0.4)
	
	await tween.finished
	current_position = target_pos
	is_moving = false
	print("Moved to: ", current_position, " world pos: ", position)

func raycast_to_grid(from: Vector3, to: Vector3) -> Vector2i:
	if not grid_map:
		return Vector2i(-1, -1)
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result:
		var grid_coords = grid_map.local_to_map(result.position)
		return Vector2i(grid_coords.x, grid_coords.z)
		
	return Vector2i(-1, -1)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	if not grid_map:
		return Vector3.ZERO
	
	# Pattern: Each grid step = +2 units in world space
	# Base calculation: (2,2) -> (5,0,5)
	# Therefore: base = (5,0,5) - (2,2)*2 = (1,0,1)
	var base_offset = Vector3(1.0, 0.0, 1.0)
	
	# Apply +2 multiplier for each grid step
	var world_pos = Vector3(
		base_offset.x + grid_pos.x * 2.0,
		0.0,
		base_offset.z + grid_pos.y * 2.0
	)
	
	return world_pos + cell_offset
