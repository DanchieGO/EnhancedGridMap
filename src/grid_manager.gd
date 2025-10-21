# grid_manager.gd
class_name GridManager
extends GridMap

signal grid_updated

@export var columns: int = 10 : set = set_columns
@export var rows: int = 10 : set = set_rows
@export var floors: int = 1 : set = set_floors

@export var normal_items: Array[int] = [0]
@export var non_walkable_items: Array[int] = [4]
@export var hover_item: int = 1
@export var start_item: int = 2
@export var end_item: int = 3

# 3x3 Tile Support Properties
@export var is_3x3_mode: bool = false
@export var three_by_three_patterns: Dictionary = {
	"default": [4, 4, 4, 4, 6, 4, 4, 4, 4]
}
@export var three_by_three_center_item: int = 6

var three_by_three_centers: Array[Vector2i] = []
var three_by_three_occupied_cells: Dictionary = {}

var grid_data: Array = []

var astar_by_floor = {}
var diagonal_movement: bool = false

func _ready():
	#if not Engine.is_editor_hint():
		#generate_grid()
	validate_item_indices()
	detect_existing_3x3_structures(0) # Detect structures on the first floor

# --- Core grid management functions ---
func set_columns(value: int):
	columns = value
	update_grid_data()

func set_rows(value: int):
	rows = value
	update_grid_data()

func set_floors(value: int):
	floors = value
	update_grid_data()
	
func generate_grid(floor_index: int = 0):
	clear_floor(floor_index)
	generate_floor(floor_index)
	update_grid_data()
	initialize_astar()
	update_astar_costs()
	detect_existing_3x3_structures(floor_index)

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
	update_grid_data()

# --- Pathfinding ---
func initialize_astar():
	astar_by_floor.clear()
	for y in range(floors):
		var astar = AStar2D.new()
		for x in range(columns):
			for z in range(rows):
				var point_id = z * columns + x
				astar.add_point(point_id, Vector2(x, z))
		
		for x in range(columns):
			for z in range(rows):
				var current_pos = Vector2i(x, z)
				var current_point_id = z * columns + x
				if not is_cell_walkable(current_pos, y):
					continue
				
				var neighbors = get_neighbors(current_pos, y)
				for neighbor in neighbors:
					if neighbor.is_walkable:
						var neighbor_id = neighbor.position.y * columns + neighbor.position.x
						var weight = 1.0 if not is_diagonal_direction(neighbor.direction) else 1.4142
						astar.connect_points(current_point_id, neighbor_id, true)
						astar.set_point_weight_scale(neighbor_id, weight)
		astar_by_floor[y] = astar
	update_astar_costs()

func find_path(start: Vector2, end: Vector2, floor_index: int = 0) -> Array:
	var astar = astar_by_floor.get(floor_index)
	if not astar:
		return []
	
	var start_point = start.y * columns + start.x
	var end_point = end.y * columns + end.x
	var path = astar.get_point_path(start_point, end_point)
	
	clear_path_visualization(floor_index)
	set_cell_item(Vector3i(start.x, floor_index, start.y), start_item)
	set_cell_item(Vector3i(end.x, floor_index, end.y), end_item)
	for point in path:
		if point != start and point != end:
			set_cell_item(Vector3i(point.x, floor_index, point.y), hover_item)
	return path
	
func update_astar_costs():
	for floor_index in range(floors):
		var astar = astar_by_floor.get(floor_index)
		if astar:
			for x in range(columns):
				for z in range(rows):
					var point_id = z * columns + x
					var cost = get_cell_cost(x, z, floor_index)
					astar.set_point_disabled(point_id, cost == INF)
					if cost != INF:
						astar.set_point_weight_scale(point_id, cost)
						
func get_cell_cost(x: int, z: int, floor_index: int = 0) -> float:
	var cell_item = get_cell_item(Vector3i(x, floor_index, z))
	if cell_item == -1 or (cell_item in non_walkable_items):
		return INF
	return 1.0

# --- 3x3 Structure Logic ---
func detect_existing_3x3_structures(floor: int = 0):
	three_by_three_centers.clear()
	three_by_three_occupied_cells.clear()
	for x in range(1, columns - 1):
		for y in range(1, rows - 1):
			var center_pos = Vector2i(x, y)
			if is_existing_3x3_structure(center_pos, floor):
				three_by_three_centers.append(center_pos)
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var cell_pos = Vector2i(x + dx, y + dy)
						three_by_three_occupied_cells[cell_pos] = center_pos

func is_existing_3x3_structure(center_pos: Vector2i, floor: int = 0) -> bool:
	var center_item = get_cell_item(Vector3i(center_pos.x, floor, center_pos.y))
	if center_item == three_by_three_center_item:
		return true
	for pattern_name in three_by_three_patterns:
		var pattern = three_by_three_patterns[pattern_name]
		if pattern.size() > 4 and center_item == pattern[4]: # Center item is at index 4
			return true
	return false

func is_3x3_structure_center(pos: Vector2i) -> bool:
	return three_by_three_centers.has(pos)

func get_3x3_structure_center(pos: Vector2i) -> Vector2i:
	if three_by_three_occupied_cells.has(pos):
		return three_by_three_occupied_cells[pos]
	return Vector2i(-1, -1)

func place_3x3_structure(center: Vector2i, pattern_name: String, floor_index: int):
	if not three_by_three_patterns.has(pattern_name):
		print("Pattern '", pattern_name, "' not found.")
		return
	var pattern = three_by_three_patterns[pattern_name]
	if pattern.size() != 9:
		push_error("3x3 pattern must have 9 items")
		return

	var idx = 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector3i(center.x + dx, floor_index, center.y + dz)
			set_cell_item(pos, pattern[idx])
			idx += 1
			
	if not three_by_three_centers.has(center):
		three_by_three_centers.append(center)
	initialize_astar()
	
func is_clear_line_of_sight(center1: Vector2i, center2: Vector2i, floor_index: int = 0) -> bool:
	if not is_3x3_structure_center(center1) or not is_3x3_structure_center(center2):
		return false
	var dx = center2.x - center1.x
	var dy = center2.y - center1.y
	var distance = Vector2(dx, dy).length()
	var is_orthogonal = (dx == 0 and abs(dy) == 4) or (dy == 0 and abs(dx) == 4)
	var is_diagonal = (abs(dx) == 4 and abs(dy) == 4)
	if not (is_orthogonal or is_diagonal):
		return false
		
	var steps = int(distance)
	for i in range(1, steps):
		var t = float(i) / steps
		var check_pos = Vector2(center1).lerp(Vector2(center2), t)
		var check_pos3i = Vector3i(round(check_pos.x), floor_index, round(check_pos.y))
		if get_cell_item(check_pos3i) in non_walkable_items:
			return false
	return true

# --- Helper Functions ---
func update_grid_data():
	grid_data.resize(floors)
	for y in range(floors):
		grid_data[y] = []
		grid_data[y].resize(rows)
		for z in range(rows):
			grid_data[y][z] = []
			grid_data[y][z].resize(columns)
			for x in range(columns):
				grid_data[y][z][x] = get_cell_item(Vector3i(x, y, z))
	grid_updated.emit()

func validate_item_indices():
	if not mesh_library: return
	var item_list = mesh_library.get_item_list()
	if item_list.is_empty(): return
	var max_index = item_list[item_list.size() - 1]
	hover_item = clamp(hover_item, 0, max_index)
	start_item = clamp(start_item, 0, max_index)
	end_item = clamp(end_item, 0, max_index)

func set_diagonal_movement(enable: bool):
	diagonal_movement = enable
	initialize_astar()

func is_cell_walkable(pos: Vector2i, floor_index: int) -> bool:
	var cell_item = get_cell_item(Vector3i(pos.x, floor_index, pos.y))
	return cell_item != -1 and not (cell_item in non_walkable_items)

func is_position_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < columns and pos.y >= 0 and pos.y < rows

func is_diagonal_direction(direction) -> bool:
	return direction in [Direction.NORTHWEST, Direction.NORTHEAST, Direction.SOUTHWEST, Direction.SOUTHEAST]

func clear_path_visualization(floor_index: int):
	for x in range(columns):
		for z in range(rows):
			var cell_pos = Vector3i(x, floor_index, z)
			var cell_item = get_cell_item(cell_pos)
			if cell_item in [hover_item, start_item, end_item]:
				set_cell_item(cell_pos, normal_items[0])
				
class NeighborInfo:
	var position: Vector2i
	var direction
	var is_walkable: bool
	func _init(pos, dir, walkable):
		position = pos; direction = dir; is_walkable = walkable

func get_neighbors(current_pos: Vector2i, floor_index: int) -> Array[NeighborInfo]:
	var neighbors: Array[NeighborInfo] = []
	var directions = {
		Direction.NORTH: Vector2i(0, -1), Direction.EAST: Vector2i(1, 0),
		Direction.SOUTH: Vector2i(0, 1),  Direction.WEST: Vector2i(-1, 0)
	}
	if diagonal_movement:
		directions[Direction.NORTHWEST] = Vector2i(-1, -1); directions[Direction.NORTHEAST] = Vector2i(1, -1)
		directions[Direction.SOUTHWEST] = Vector2i(-1, 1);  directions[Direction.SOUTHEAST] = Vector2i(1, 1)

	for dir in directions:
		var neighbor_pos = current_pos + directions[dir]
		if is_position_valid(neighbor_pos):
			neighbors.append(NeighborInfo.new(neighbor_pos, dir, is_cell_walkable(neighbor_pos, floor_index)))
	return neighbors
	
enum Direction { NORTH, EAST, SOUTH, WEST, NORTHWEST, NORTHEAST, SOUTHWEST, SOUTHEAST }
