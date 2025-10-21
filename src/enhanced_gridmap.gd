@tool
class_name EnhancedGridMap
extends GridMap

@export var columns: int = 120
@export var rows: int = 120
@export var floors: int = 3
@export var auto_generate: bool = false

@export var normal_items: Array[int] = [0]
@export var non_walkable_items: Array[int] = [4]
@export var hover_item: int = 1
@export var start_item: int = 2
@export var end_item: int = 3

# 3x3 Tile Support Properties
@export var is_3x3_mode: bool = false

# Track which cells are part of 3x3 structures
var three_by_three_centers: Array[Vector2i] = []

signal grid_updated

# A* Pathfinding variables
var astar: AStar2D
var pathfinding_enabled: bool = true

func _ready():
	if auto_generate:
		generate_grid(0)
	initialize_astar()

func initialize_astar():
	#"""Initialize the A* pathfinding system"""
	astar = AStar2D.new()
	update_pathfinding_grid()

func update_pathfinding_grid():
	#"""Update the A* grid with current walkable cells"""
	if not astar:
		return
	
	astar.clear()
	
	# Add all walkable cells as points
	for x in range(columns):
		for z in range(rows):
			var point_id = z * columns + x
			var cell_item = get_cell_item(Vector3i(x, 0, z))
			
			# Only add walkable cells
			if cell_item != -1 and not non_walkable_items.has(cell_item):
				astar.add_point(point_id, Vector2(x, z))
	
	# Connect adjacent walkable cells
	for x in range(columns):
		for z in range(rows):
			var current_id = z * columns + x
			var cell_item = get_cell_item(Vector3i(x, 0, z))
			
			# Only process walkable cells
			if cell_item != -1 and not non_walkable_items.has(cell_item):
				# Check all 8 neighbors
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if dx == 0 and dz == 0:
							continue
						
						var nx = x + dx
						var nz = z + dz
						
						# Check bounds
						if nx >= 0 and nx < columns and nz >= 0 and nz < rows:
							var neighbor_item = get_cell_item(Vector3i(nx, 0, nz))
							if neighbor_item != -1 and not non_walkable_items.has(neighbor_item):
								var neighbor_id = nz * columns + nx
								# Connect points
								astar.connect_points(current_id, neighbor_id)
								
								# Set weight for diagonal movement
								var weight = 1.0
								if dx != 0 and dz != 0:
									weight = 1.414  # sqrt(2) for diagonal
								astar.set_point_weight_scale(neighbor_id, weight)

func find_path(start: Vector2i, end: Vector2i) -> Array:
	#"""Find path from start to end using A*"""
	if not astar or not pathfinding_enabled:
		return []
	
	# Check if start and end are valid
	if start.x < 0 or start.x >= columns or start.y < 0 or start.y >= rows:
		return []
	if end.x < 0 or end.x >= columns or end.y < 0 or end.y >= rows:
		return []
	
	var start_id = start.y * columns + start.x
	var end_id = end.y * columns + end.x
	
	# Check if points exist in A*
	if not astar.has_point(start_id) or not astar.has_point(end_id):
		return []
	
	var path_points = astar.get_point_path(start_id, end_id)
	
	# Convert back to Vector2i array
	var path: Array[Vector2i] = []
	for point in path_points:
		path.append(Vector2i(int(point.x), int(point.y)))
	
	return path

func generate_grid(floor: int):
	clear_grid(floor)
	
	if is_3x3_mode:
		# Create 3x3 structures
		for x in range(1, columns - 1, 3):
			for z in range(1, rows - 1, 3):
				create_3x3_structure(x, z, floor)
	else:
		# Create normal grid
		for x in range(columns):
			for z in range(rows):
				set_cell_item(Vector3i(x, floor, z), normal_items[0])
	
	grid_updated.emit()

func create_3x3_structure(center_x: int, center_z: int, floor: int):
	for x_offset in range(-1, 2):
		for z_offset in range(-1, 2):
			var pos = Vector3i(center_x + x_offset, floor, center_z + z_offset)
			set_cell_item(pos, normal_items[0])
	
	three_by_three_centers.append(Vector2i(center_x, center_z))

func clear_grid(floor: int):
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, floor, z), -1)
	
	three_by_three_centers.clear()
	grid_updated.emit()
