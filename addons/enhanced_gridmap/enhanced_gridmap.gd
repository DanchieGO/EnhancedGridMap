@tool
class_name EnhancedGridMap
extends GridMap

signal mesh_library_changed
signal grid_updated

@export var columns: int = 10 : set = set_columns
@export var rows: int = 10 : set = set_rows
@export var floors: int = 3 : set = set_floors
@export var auto_generate: bool = false : set = set_auto_generate

@export var normal_items: Array[int] = [0]
@export var non_walkable_items: Array[int] = [4]
@export var hover_item: int = 1
@export var start_item: int = 2
@export var end_item: int = 3

var current_mesh_library: MeshLibrary
var grid_data: Array = [] # 3D array [floor][row][column]

# A* Pathfinding variables (per floor)
var astar_by_floor = {} # Dictionary of AStar2D instances per floor
var path = []
var last_path_visuals: Dictionary = {} # Stores original cell data before visualization

# Update the obstacle items array to use your specified item indices
@export var obstacle_items: Array[int] = [12, 13, 14, 15]  # Obstacle items in mesh library
@export var obstacle_directions: Dictionary = {}  # Store direction for each placed obstacle: {Vector3i position: Direction}

# Dictionary to store obstacle information: {cell_pos: orientation}
# orientation: 0=North, 1=East, 2=South, 3=West
var obstacles = {}

# Dictionary to store the root position and size of multi-cell objects
# Format: {Vector3i_root_pos: Vector2i_size}
@export var multi_cell_objects: Dictionary = {}

# A special constant to mark cells that are part of a larger object.
const MULTI_CELL_OCCUPIED = -2

# Direction and movement systems
enum Direction {
	NORTHWEST, NORTH, NORTHEAST,
	WEST, CENTER, EAST,
	SOUTHWEST, SOUTH, SOUTHEAST,
	BLOCKED_NORTH = 10,
	BLOCKED_EAST = 11, 
	BLOCKED_SOUTH = 12,
	BLOCKED_WEST = 13
}

var diagonal_movement: bool = false


class NeighborInfo:
	var position: Vector2i
	var direction: Direction
	var is_walkable: bool
	
	func _init(pos: Vector2i, dir: Direction, walkable: bool):
		position = pos
		direction = dir
		is_walkable = walkable

func _ready():
	mesh_library_changed.connect(_on_mesh_library_changed)
	
	if not Engine.is_editor_hint() and auto_generate and get_used_cells().is_empty():
		generate_grid()
	
	update_grid_data()
	initialize_astar() 
	validate_item_indices()


func _find_multi_cell_root(position: Vector3i) -> Vector3i:
	var multi_cell_data = get("multi_cell_objects")
	if multi_cell_data is Dictionary:
		if multi_cell_data.has(position):
			return position
		
		for root in multi_cell_data:
			var size = multi_cell_data[root]
			var offset = Vector2i(floor(size.x / 2.0), floor(size.y / 2.0))
			var top_left_pos = Vector3i(root.x - offset.x, root.y, root.z - offset.y)

			if position.y == root.y and \
			   position.x >= top_left_pos.x and position.x < (top_left_pos.x + size.x) and \
			   position.z >= top_left_pos.z and position.z < (top_left_pos.z + size.y):
				return root
	
	return Vector3i(-1, -1, -1)

func set_cell_item(position: Vector3i, item: int, orientation: int = 0):
	var root_pos = _find_multi_cell_root(position)
	
	if root_pos.x != -1:
		var multi_cell_data = get("multi_cell_objects")
		if multi_cell_data is Dictionary and multi_cell_data.has(root_pos):
			var size = multi_cell_data[root_pos]
			var offset = Vector2i(floor(size.x / 2.0), floor(size.y / 2.0))
			var top_left_pos = Vector3i(root_pos.x - offset.x, root_pos.y, root_pos.z - offset.y)
			
			multi_cell_data.erase(root_pos)
			
			for z in range(top_left_pos.z, top_left_pos.z + size.y):
				for x in range(top_left_pos.x, top_left_pos.x + size.x):
					var clear_pos = Vector3i(x, top_left_pos.y, z)
					if is_position_valid(Vector2i(clear_pos.x, clear_pos.z)):
						super.set_cell_item(clear_pos, -1, 0)

	if is_position_valid(Vector2i(position.x, position.z)):
		super.set_cell_item(position, item, orientation)

func set_multi_cell_item(root_position: Vector3i, item_id: int, size: Vector2i, orientation: int = 0):
	var offset = Vector2i(floor(size.x / 2.0), floor(size.y / 2.0))
	var top_left_pos = Vector3i(root_position.x - offset.x, root_position.y, root_position.z - offset.y)
	var final_pos = top_left_pos + Vector3i(size.x - 1, 0, size.y - 1)

	if not is_position_valid(Vector2i(top_left_pos.x, top_left_pos.z)) or not is_position_valid(Vector2i(final_pos.x, final_pos.z)):
		print("Cannot place multi-cell object at ", root_position, ". Object exceeds grid boundaries.")
		update_grid_data()
		return
		
	for z in range(top_left_pos.z, top_left_pos.z + size.y):
		for x in range(top_left_pos.x, top_left_pos.x + size.x):
			set_cell_item(Vector3i(x, root_position.y, z), -1, 0)

	super.set_cell_item(root_position, item_id, orientation)
	
	for z in range(top_left_pos.z, top_left_pos.z + size.y):
		for x in range(top_left_pos.x, top_left_pos.x + size.x):
			var current_pos = Vector3i(x, top_left_pos.y, z)
			if current_pos == root_position:
				continue
			super.set_cell_item(current_pos, MULTI_CELL_OCCUPIED)
			
	multi_cell_objects[root_position] = size
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()

func set_columns(value: int):
	columns = value
	if auto_generate: generate_grid()
	else: update_grid_data()

func set_rows(value: int):
	rows = value
	if auto_generate: generate_grid()
	else: update_grid_data()

func set_floors(value: int):
	floors = value
	if auto_generate: generate_grid()
	else: update_grid_data()

func set_auto_generate(value: bool):
	auto_generate = value
	if auto_generate: generate_grid()

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
	
	if normal_items.is_empty(): normal_items = [0]
	if non_walkable_items.is_empty(): non_walkable_items = [max_index]

func generate_grid(floor_index: int = -1):
	if floor_index == -1:
		clear_grid(-1)
		for y in range(floors):
			generate_floor(y)
	else:
		clear_floor(floor_index)
		generate_floor(floor_index)
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()

func generate_floor(floor_index: int):
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return
	
	validate_item_indices()
	
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, floor_index, z), normal_items[0])

func clear_floor(floor_index: int):
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, floor_index, z), -1)

	var multi_cell_data = get("multi_cell_objects")
	if not multi_cell_data is Dictionary:
		update_grid_data()
		return

	var keys_to_remove = []
	for key in multi_cell_data.keys():
		if key.y == floor_index: keys_to_remove.append(key)
	for key in keys_to_remove: multi_cell_data.erase(key)
		
	update_grid_data()

func clear_grid(floor_index: int = -1):
	if floor_index == -1:
		clear()
		multi_cell_objects.clear()
	else:
		clear_floor(floor_index)
	update_grid_data()

func update_grid_data():
	grid_data.clear()
	for y in range(floors):
		var floor_data = []
		for z in range(rows):
			var row = []
			for x in range(columns):
				row.append(get_cell_item(Vector3i(x, y, z)))
			floor_data.append(row)
		grid_data.append(floor_data)
	emit_signal("grid_updated")
	
func _on_mesh_library_changed():
	validate_item_indices()
	if auto_generate:
		generate_grid()

func _set(property, value):
	if property == "mesh_library":
		mesh_library = value
		if is_inside_tree(): # Ensure node is ready
			_on_mesh_library_changed()
		return true
	return false


# --- A* PATHFINDING ---

func is_position_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < columns and pos.y >= 0 and pos.y < rows

# NEW: A single source of truth for whether a cell is traversable.
func is_cell_traversable(pos: Vector3i) -> bool:
	var item = get_cell_item(pos)
	if item == -1 or item == MULTI_CELL_OCCUPIED or item in non_walkable_items:
		return false
	return true
	
func _get_pathfinding_target(pos: Vector3i) -> Vector3i:
	if not is_cell_traversable(pos):
		# If it's not traversable, check if it's part of a multi-cell object.
		# If so, the target is the object's root (which must be traversable itself).
		var root = _find_multi_cell_root(pos)
		if root.x != -1 and is_cell_traversable(root):
			return root
		else:
			return Vector3i(-1, -1, -1) # Invalid target
	else:
		# If it is traversable, it's its own target. This covers normal cells and roots.
		return pos

func initialize_astar():
	astar_by_floor.clear()
	for y in range(floors):
		var astar = AStar2D.new()
		
		# Add all cells as points in the graph
		for x in range(columns):
			for z in range(rows):
				var point_id = z * columns + x
				astar.add_point(point_id, Vector2(x, z))
		
		# Now, create connections based on walkability and targets
		for x in range(columns):
			for z in range(rows):
				var start_pos_3d = Vector3i(x, y, z)
				
				# Determine the true starting point for pathfinding from this cell
				var start_target = _get_pathfinding_target(start_pos_3d)
				if start_target.x == -1:
					continue # This cell is not a valid starting point
				
				var start_id = start_target.z * columns + start_target.x
				
				# Check its neighbors
				var directions = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
				if diagonal_movement:
					directions.append_array([Vector2i(-1,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)])
					
				for offset in directions:
					var neighbor_pos_2d = Vector2i(x + offset.x, z + offset.y)
					if not is_position_valid(neighbor_pos_2d):
						continue
					
					var neighbor_pos_3d = Vector3i(neighbor_pos_2d.x, y, neighbor_pos_2d.y)
					
					# Determine the true destination point
					var end_target = _get_pathfinding_target(neighbor_pos_3d)
					if end_target.x == -1 or start_target == end_target:
						continue # Not a valid or unique destination
					
					var end_id = end_target.z * columns + end_target.x
					
					# Connect the two true points if they aren't already connected
					if not astar.are_points_connected(start_id, end_id):
						astar.connect_points(start_id, end_id, true)

		astar_by_floor[y] = astar
	update_astar_costs()

func find_path(start: Vector2, end: Vector2, floor_index: int = 0, clear_path_visual: bool = true) -> Array:
	var astar = astar_by_floor.get(floor_index)
	if not astar: return []

	if clear_path_visual: clear_path_visualization(floor_index)

	var start_pos_3d = Vector3i(start.x, floor_index, start.y)
	var end_pos_3d = Vector3i(end.x, floor_index, end.y)

	var final_start = _get_pathfinding_target(start_pos_3d)
	var final_end = _get_pathfinding_target(end_pos_3d)

	if final_start.x == -1 or final_end.x == -1:
		print("No path found: Start or end point is not on a walkable tile.")
		return []

	var start_point = final_start.z * columns + final_start.x
	var end_point = final_end.z * columns + final_end.x
	
	path = astar.get_point_path(start_point, end_point)
	
	# --- Visualization ---
	if not path.is_empty():
		last_path_visuals[final_start] = [get_cell_item(final_start), get_cell_item_orientation(final_start)]
		super.set_cell_item(final_start, start_item)
		
		last_path_visuals[final_end] = [get_cell_item(final_end), get_cell_item_orientation(final_end)]
		super.set_cell_item(final_end, end_item)
		
		for point_vec in path:
			var point_3d = Vector3i(point_vec.x, floor_index, point_vec.y)
			if point_3d != final_start and point_3d != final_end:
				last_path_visuals[point_3d] = [get_cell_item(point_3d), get_cell_item_orientation(point_3d)]
				super.set_cell_item(point_3d, hover_item)
	
	return path

func clear_path_visualization(floor_index: int = 0):
	for pos in last_path_visuals:
		var data = last_path_visuals[pos]
		super.set_cell_item(pos, data[0], data[1])
	last_path_visuals.clear()

# REVISED: This now uses the single source of truth for walkability.
func update_astar_costs():
	for floor_index in range(floors):
		var astar = astar_by_floor.get(floor_index)
		if astar:
			for x in range(columns):
				for z in range(rows):
					var point_id = z * columns + x
					var pos_3d = Vector3i(x, floor_index, z)
					
					if astar.has_point(point_id):
						var is_disabled = not is_cell_traversable(pos_3d)
						astar.set_point_disabled(point_id, is_disabled)


func set_diagonal_movement(enable: bool):
	diagonal_movement = enable
	initialize_astar()
	
func is_movement_blocked(from_pos: Vector2i, to_pos: Vector2i, floor_index: int = 0) -> bool:
	return false # Placeholder for future obstacle logic
