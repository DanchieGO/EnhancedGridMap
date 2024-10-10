@tool
class_name EnhancedGridMap
extends GridMap

signal mesh_library_changed
signal grid_updated

@export var columns: int = 10 : set = set_columns
@export var rows: int = 10 : set = set_rows
@export var auto_generate: bool = false : set = set_auto_generate

@export var normal_items: Array[int] = [0]
@export var non_walkable_items: Array[int] = [4]
@export var hover_item: int = 1
@export var start_item: int = 2
@export var end_item: int = 3

var current_mesh_library: MeshLibrary
var grid_data: Array = []

# A* Pathfinding variables
var astar = AStar2D.new()
var path = []

# Item states
enum ItemState {NORMAL, HOVER, START, END, NON_WALKABLE}

# Add this to the class variables
var diagonal_movement: bool = false


func _ready():
	mesh_library_changed.connect(_on_mesh_library_changed)
	if not Engine.is_editor_hint() and auto_generate:
		generate_grid()
	
	# Validate item indices
	validate_item_indices()

func validate_item_indices():
	if not mesh_library:
		print("Warning: No MeshLibrary assigned to GridMap")
		return
	
	var item_list = mesh_library.get_item_list()
	var max_index = item_list.size() - 1
	
	normal_items = normal_items.filter(func(item): return item >= 0 and item <= max_index)
	hover_item = clamp(hover_item, 0, max_index)
	start_item = clamp(start_item, 0, max_index)
	end_item = clamp(end_item, 0, max_index)
	non_walkable_items = non_walkable_items.filter(func(item): return item >= 0 and item <= max_index)
	
	if normal_items.is_empty():
		normal_items = [0]
	if non_walkable_items.is_empty():
		non_walkable_items = [max_index]

func set_columns(value: int):
	columns = value
	if auto_generate:
		generate_grid()
	else:
		update_grid_data()

func set_rows(value: int):
	rows = value
	if auto_generate:
		generate_grid()
	else:
		update_grid_data()

func set_auto_generate(value: bool):
	auto_generate = value
	if auto_generate:
		generate_grid()

# Override the existing functions to update A* data
func generate_grid():
	clear()
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return
	
	validate_item_indices()
	
	current_mesh_library = mesh_library
	var item_list = mesh_library.get_item_list()
	if item_list.size() < 5:
		print("Warning: MeshLibrary should have at least 5 items")
	
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, 0, z), normal_items[0])
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()

func clear_grid():
	clear()
	update_grid_data()

func randomize_grid():
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return
	
	validate_item_indices()
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for x in range(columns):
		for z in range(rows):
			var random_value = rng.randi() % 100  # Generate a random number between 0 and 99
			var item_index
			if random_value < 80:
				item_index = normal_items[rng.randi() % normal_items.size()]
			else:
				item_index = non_walkable_items[rng.randi() % non_walkable_items.size()]
			set_cell_from_data(x, z, item_index)
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()
	emit_signal("grid_updated")

func randomize_grid_custom(randomize_states: Array):
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for x in range(columns):
		for z in range(rows):
			var random_value = rng.randf() * 100  # Generate a random number between 0 and 100
			var accumulated_percentage = 0
			var selected_state = null

			for state in randomize_states:
				accumulated_percentage += state.randomize_percentage
				if random_value <= accumulated_percentage:
					selected_state = state
					break

			if selected_state:
				set_cell_from_data(x, z, selected_state.id)
			else:
				set_cell_from_data(x, z, randomize_states[0].id)  # Default to the first state if no match

	update_grid_data()
	initialize_astar()
	update_astar_costs()
	emit_signal("grid_updated")

func fill_grid(item_index: int):
	if not mesh_library:
		print("No MeshLibrary assigned to GridMap")
		return
	
	if item_index < 0 or item_index >= mesh_library.get_item_list().size():
		print("Invalid item index")
		return
	
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, 0, z), item_index)
	
	update_grid_data()

func _on_mesh_library_changed():
	validate_item_indices()
	if auto_generate:
		generate_grid()

func _set(property, value):
	if property == "mesh_library":
		mesh_library = value
		_on_mesh_library_changed()
		return true
	return false

func update_grid_data():
	grid_data.clear()
	for z in range(rows):
		var row = []
		for x in range(columns):
			row.append(get_cell_item(Vector3i(x, 0, z)))
		grid_data.append(row)
	emit_signal("grid_updated")

func set_cell_from_data(x: int, z: int, item_index: int):
	if x >= 0 and x < columns and z >= 0 and z < rows:
		if not mesh_library:
			print("Error: No MeshLibrary assigned to GridMap")
			return
		
		var item_list = mesh_library.get_item_list()
		var max_index = item_list.size() - 1
		var valid_index = clamp(item_index, 0, max_index)
		
		set_cell_item(Vector3i(x, 0, z), valid_index)
		grid_data[z][x] = valid_index
		var point_id = z * columns + x
		var cost = get_cell_cost(x, z)
		if cost == INF:
			astar.set_point_disabled(point_id, true)
		else:
			astar.set_point_disabled(point_id, false)
			astar.set_point_weight_scale(point_id, cost)

# New A* Pathfinding functions
# Modify the initialize_astar function
func initialize_astar():
	astar.clear()
	for x in range(columns):
		for z in range(rows):
			var point_id = z * columns + x
			astar.add_point(point_id, Vector2(x, z))
			
			# Connect to neighboring points
			if x > 0:
				astar.connect_points(point_id, point_id - 1)
			if z > 0:
				astar.connect_points(point_id, point_id - columns)
			
			# Add diagonal connections if diagonal movement is enabled
			if diagonal_movement:
				if x > 0 and z > 0:
					astar.connect_points(point_id, point_id - columns - 1)  # Top-left
				if x < columns - 1 and z > 0:
					astar.connect_points(point_id, point_id - columns + 1)  # Top-right
	
	update_astar_costs()

# Add this function to toggle diagonal movement
func set_diagonal_movement(enable: bool):
	diagonal_movement = enable
	initialize_astar()  # Reinitialize the A* graph with new connections

func set_point_solid(x: int, z: int, is_solid: bool):
	var point_id = z * columns + x
	astar.set_point_disabled(point_id, is_solid)

func find_path(start: Vector2, end: Vector2) -> Array:
	var start_point = start.y * columns + start.x
	var end_point = end.y * columns + end.x
	path = astar.get_point_path(start_point, end_point)
	
	# Visualize the path
	clear_path_visualization()
	set_cell_item(Vector3i(start.x, 0, start.y), start_item)
	set_cell_item(Vector3i(end.x, 0, end.y), end_item)
	for point in path:
		if point != start and point != end:
			set_cell_item(Vector3i(point.x, 0, point.y), hover_item)
	
	return path

func clear_path_visualization():
	for x in range(columns):
		for z in range(rows):
			var cell_item = get_cell_item(Vector3i(x, 0, z))
			if cell_item == hover_item or cell_item == start_item or cell_item == end_item:
				set_cell_item(Vector3i(x, 0, z), normal_items[0])

func get_cell_cost(x: int, z: int) -> float:
	var cell_item = get_cell_item(Vector3i(x, 0, z))
	if cell_item in non_walkable_items:
		return INF
	elif cell_item == hover_item:
		return 0.5
	elif cell_item == start_item or cell_item == end_item:
		return 0.0
	return 1.0

func update_astar_costs():
	for x in range(columns):
		for z in range(rows):
			var point_id = z * columns + x
			var cost = get_cell_cost(x, z)
			if cost == INF:
				astar.set_point_disabled(point_id, true)
			else:
				astar.set_point_disabled(point_id, false)
				astar.set_point_weight_scale(point_id, cost)

func get_cell_rotation(position: Vector3i) -> int:
	return get_cell_item_orientation(position)

func set_cell_rotation(position: Vector3i, mode: int):
	var item = get_cell_item(position)
	if item != INVALID_CELL_ITEM:
		var orientation = int(mode)
		set_cell_item(position, item, orientation)
