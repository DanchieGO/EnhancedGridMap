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

# Update the obstacle items array to use your specified item indices
@export var obstacle_items: Array[int] = [12, 13, 14, 15]  # Obstacle items in mesh library
@export var obstacle_directions: Dictionary = {}  # Store direction for each placed obstacle: {Vector3i position: Direction}

# Dictionary to store obstacle information: {cell_pos: orientation}
# orientation: 0=North, 1=East, 2=South, 3=West
var obstacles = {}

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
	var is_long_jump: bool = false      # <-- new

	func _init(pos: Vector2i, dir: Direction, walkable: bool, long := false):
		position = pos
		direction = dir
		is_walkable = walkable
		is_long_jump = long

func _ready():
	mesh_library_changed.connect(_on_mesh_library_changed)
	if not Engine.is_editor_hint() and auto_generate:
		generate_grid()
	validate_item_indices()

# Core grid management functions
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

func set_floors(value: int):
	floors = value
	if auto_generate:
		generate_grid()
	else:
		update_grid_data()

func set_auto_generate(value: bool):
	auto_generate = value
	if auto_generate:
		generate_grid()

# Item validation
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

# Grid generation and management
func generate_grid(floor_index: int = -1):
	if floor_index == -1:
		clear()
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
	
	current_mesh_library = mesh_library
	var item_list = mesh_library.get_item_list()
	if item_list.size() < 5:
		print("Warning: MeshLibrary should have at least 5 items")
	
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, floor_index, z), normal_items[0])

# Grid operations
func clear_floor(floor_index: int):
	for x in range(columns):
		for z in range(rows):
			set_cell_item(Vector3i(x, floor_index, z), -1)
	update_grid_data()

func clear_grid(floor_index: int = -1):
	if floor_index == -1:
		clear()
	else:
		clear_floor(floor_index)
	update_grid_data()

func fill_grid(item_index: int, floor_index: int = -1):
	if not mesh_library:
		print("No MeshLibrary assigned to GridMap")
		return
	
	if item_index < 0 or item_index >= mesh_library.get_item_list().size():
		print("Invalid item index")
		return
	
	if floor_index == -1:
		for y in range(floors):
			fill_floor(item_index, y)
	else:
		if floor_index >= 0 and floor_index < floors:
			fill_floor(item_index, floor_index)
		else:
			print("Invalid floor index")
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()

func fill_floor(item_index: int, floor_index: int):
	for x in range(columns):
		for z in range(rows):
			var cell_pos = Vector3i(x, floor_index, z)
			var current_orientation = get_cell_item_orientation(cell_pos)
			set_cell_item(cell_pos, item_index, current_orientation)

# Randomization functions
func randomize_grid(floor_index: int = -1):
	if floor_index == -1:
		for y in range(floors):
			randomize_floor(y)
	else:
		randomize_floor(floor_index)
	
	update_grid_data()
	initialize_astar()
	update_astar_costs()

func randomize_floor(floor_index: int):
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return
	
	validate_item_indices()
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for x in range(columns):
		for z in range(rows):
			var random_value = rng.randi() % 100
			var item_index
			if random_value < 80:
				item_index = normal_items[rng.randi() % normal_items.size()]
			else:
				item_index = non_walkable_items[rng.randi() % non_walkable_items.size()]
			set_cell_item(Vector3i(x, floor_index, z), item_index)

func randomize_grid_custom(randomize_states: Array, floor_index: int = -1):
	if not mesh_library:
		print("Error: No MeshLibrary assigned to GridMap")
		return

	if floor_index == -1:
		for y in range(floors):
			randomize_floor_custom(randomize_states, y)
	else:
		if floor_index >= 0 and floor_index < floors:
			randomize_floor_custom(randomize_states, floor_index)
		else:
			print("Invalid floor index")

	update_grid_data()
	initialize_astar()
	update_astar_costs()

func randomize_floor_custom(randomize_states: Array, floor_index: int):
	if randomize_states.is_empty():
		print("No randomize states provided")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for x in range(columns):
		for z in range(rows):
			var cell_pos = Vector3i(x, floor_index, z)
			var random_value = rng.randf() * 100
			var accumulated_percentage = 0
			var selected_state = null

			for state in randomize_states:
				if state.include_in_randomize:
					accumulated_percentage += state.randomize_percentage
					if random_value <= accumulated_percentage:
						selected_state = state
						break

			var current_orientation = get_cell_item_orientation(cell_pos)
			
			if selected_state:
				set_cell_item(cell_pos, selected_state.id, current_orientation)
			else:
				var fallback_state = null
				for state in randomize_states:
					if state.include_in_randomize:
						fallback_state = state
						break
				
				if fallback_state:
					set_cell_item(cell_pos, fallback_state.id, current_orientation)
				else:
					set_cell_item(cell_pos, normal_items[0], current_orientation)


#func get_neighbors(current_pos: Vector2i, floor_index: int) -> Array[NeighborInfo]:
	#var neighbors: Array[NeighborInfo] = []
	#
	#var directions = {
		#Direction.NORTHWEST: Vector2i(-1, -1),
		#Direction.NORTH: Vector2i(0, -1),
		#Direction.NORTHEAST: Vector2i(1, -1),
		#Direction.WEST: Vector2i(-1, 0),
		#Direction.EAST: Vector2i(1, 0),
		#Direction.SOUTHWEST: Vector2i(-1, 1),
		#Direction.SOUTH: Vector2i(0, 1),
		#Direction.SOUTHEAST: Vector2i(1, 1)
	#}
	#
	#for dir in directions:
		#var offset = directions[dir]
		#var neighbor_pos = current_pos + offset
		#
		#if is_position_valid(neighbor_pos):
			#var is_walkable = is_cell_walkable(neighbor_pos, floor_index)
			#
			## Check for obstacles - specifically for orthogonal movement
			#if not is_diagonal_direction(dir) and is_blocked_by_obstacle(current_pos, neighbor_pos, 3):
				#is_walkable = false
			#
			## Special handling for diagonal movement
			#if is_diagonal_direction(dir):
				#var adjacent1: Vector2i
				#var adjacent2: Vector2i
				#
				#match dir:
					#Direction.NORTHWEST:
						#adjacent1 = current_pos + Vector2i(-1, 0) # West
						#adjacent2 = current_pos + Vector2i(0, -1) # North
					#Direction.NORTHEAST:
						#adjacent1 = current_pos + Vector2i(1, 0)  # East
						#adjacent2 = current_pos + Vector2i(0, -1) # North
					#Direction.SOUTHWEST:
						#adjacent1 = current_pos + Vector2i(-1, 0) # West
						#adjacent2 = current_pos + Vector2i(0, 1)  # South
					#Direction.SOUTHEAST:
						#adjacent1 = current_pos + Vector2i(1, 0)  # East
						#adjacent2 = current_pos + Vector2i(0, 1)  # South
				#
				## For diagonal movement, both adjacent cells must be walkable
				## AND the movements to those adjacent cells must not be blocked
				#is_walkable = is_walkable and \
						   #is_position_valid(adjacent1) and is_cell_walkable(adjacent1, floor_index) and \
						   #is_position_valid(adjacent2) and is_cell_walkable(adjacent2, floor_index) and \
						   #not is_blocked_by_obstacle(current_pos, adjacent1, 3) and \
						   #not is_blocked_by_obstacle(current_pos, adjacent2, 3)
			#
			#if diagonal_movement or not is_diagonal_direction(dir):
				#neighbors.append(NeighborInfo.new(neighbor_pos, dir, is_walkable))
	#
	#return neighbors

#func get_neighbors(current_pos: Vector2i, floor_index: int) -> Array[NeighborInfo]:
	#var neighbors: Array[NeighborInfo] = []
	#
	## Four orthogonal directions
	#var directions = {
		#Direction.NORTH: Vector2i(0, -1),
		#Direction.EAST: Vector2i(1, 0),
		#Direction.SOUTH: Vector2i(0, 1),
		#Direction.WEST: Vector2i(-1, 0)
	#}
	#
	## Add diagonal directions if enabled
	#if diagonal_movement:
		#directions[Direction.NORTHWEST] = Vector2i(-1, -1)
		#directions[Direction.NORTHEAST] = Vector2i(1, -1)
		#directions[Direction.SOUTHWEST] = Vector2i(-1, 1)
		#directions[Direction.SOUTHEAST] = Vector2i(1, 1)
	#
	#for dir in directions:
		#var offset = directions[dir]
		#var neighbor_pos = current_pos + offset
		#
		#if is_position_valid(neighbor_pos):
			#var is_walkable = is_cell_walkable(neighbor_pos, floor_index)
			#
			## Check if movement to this neighbor is blocked by obstacles
			#if not is_diagonal_direction(dir) and is_movement_blocked(current_pos, neighbor_pos, floor_index):
				#is_walkable = false
			#
			#if is_diagonal_direction(dir):
				## For diagonal movement, check if both orthogonal paths are blocked
				#var mid1 = Vector2i(neighbor_pos.x, current_pos.y)
				#var mid2 = Vector2i(current_pos.x, neighbor_pos.y)
				#
				#var path1_blocked = is_movement_blocked(current_pos, mid1, floor_index)
				#var path2_blocked = is_movement_blocked(current_pos, mid2, floor_index)
				#
				#if path1_blocked and path2_blocked:
					#is_walkable = false
			#
			#if is_walkable:
				#neighbors.append(NeighborInfo.new(neighbor_pos, dir, is_walkable))
	#
	#return neighbors

func get_neighbors(current_pos: Vector2i, floor_index: int) -> Array[NeighborInfo]:
	var neighbors: Array[NeighborInfo] = []

	# 8 directions
	var dirs = {
		Direction.NORTHWEST: Vector2i(-1, -1),
		Direction.NORTH:     Vector2i( 0, -1),
		Direction.NORTHEAST: Vector2i( 1, -1),
		Direction.WEST:      Vector2i(-1,  0),
		Direction.EAST:      Vector2i( 1,  0),
		Direction.SOUTHWEST: Vector2i(-1,  1),
		Direction.SOUTH:     Vector2i( 0,  1),
		Direction.SOUTHEAST: Vector2i( 1,  1)
	}

	for dir in dirs:
		var offset   = dirs[dir]
		var neighbour = current_pos + offset

		# immediate neighbour
		if is_position_valid(neighbour):
			var walk = is_cell_walkable(neighbour, floor_index)
			if walk:
				neighbors.append(NeighborInfo.new(neighbour, dir, true, false))
				continue

			# immediate cell is UN-walkable → try to jump one step further
			var jump_pos = neighbour + offset
			if is_position_valid(jump_pos) and is_cell_walkable(jump_pos, floor_index):
				neighbors.append(NeighborInfo.new(jump_pos, dir, true, true))
	return neighbors

# Helper functions for neighbor checking
func is_diagonal_direction(direction: Direction) -> bool:
	return direction in [Direction.NORTHWEST, Direction.NORTHEAST, 
						Direction.SOUTHWEST, Direction.SOUTHEAST]

func is_position_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < columns and pos.y >= 0 and pos.y < rows

func is_cell_walkable(pos: Vector2i, floor_index: int) -> bool:
	var cell_item = get_cell_item(Vector3i(pos.x, floor_index, pos.y))
	return cell_item != -1 and not (cell_item in non_walkable_items)

## Improved A* pathfinding
#func initialize_astar():
	#astar_by_floor.clear()
	#for y in range(floors):
		#var astar = AStar2D.new()
		#
		## Add all points
		#for x in range(columns):
			#for z in range(rows):
				#var point_id = z * columns + x
				#astar.add_point(point_id, Vector2(x, z))
		#
		## Connect points based on neighbors
		#for x in range(columns):
			#for z in range(rows):
				#var current_pos = Vector2i(x, z)
				#var current_point_id = z * columns + x
				#
				#if not is_cell_walkable(current_pos, y):
					#continue
				#
				#var neighbors = get_neighbors(current_pos, y)
				#
				### inside initialize_astar(), inner loop:
				##for neighbor in neighbors:          # neighbours now contains 8 directions
					##if neighbor.is_walkable:
						##var neighbor_id = neighbor.position.y * columns + neighbor.position.x
						### ALWAYS rebuild the edge (cardinal or diagonal)
						##astar.disconnect_points(current_point_id, neighbor_id)
						##var weight = 1.0 if not is_diagonal_direction(neighbor.direction) else 1.4142
						##astar.connect_points(current_point_id, neighbor_id, true)
						##astar.set_point_weight_scale(neighbor_id, weight)
				#
				#for neighbor in neighbors:
					#if neighbor.is_walkable:
						#var neighbor_id = neighbor.position.y * columns + neighbor.position.x
#
						#astar.disconnect_points(current_point_id, neighbor_id)
						#var weight = 1.0
						#if neighbor.is_long_jump: weight = 2.0   # one extra cell = double cost
						#astar.connect_points(current_point_id, neighbor_id, true)
						#astar.set_point_weight_scale(neighbor_id, weight)
				#
				##for neighbor in neighbors:
					##if neighbor.is_walkable:
						##var neighbor_id = neighbor.position.y * columns + neighbor.position.x
						##
						##if not astar.are_points_connected(current_point_id, neighbor_id):
							##var weight = 1.0 if not is_diagonal_direction(neighbor.direction) else 1.4142
							##
							### Check if movement is allowed by obstacles
							##if not is_blocked_by_obstacle(current_pos, neighbor.position, 3):
								##astar.connect_points(current_point_id, neighbor_id, true)
								##astar.set_point_weight_scale(neighbor_id, weight)
		#
		#astar_by_floor[y] = astar
	#initialize_astar_with_3x3()
	#update_astar_costs()


func initialize_astar():
	initialize_astar_with_3x3()


func find_path(start: Vector2, end: Vector2, floor_index: int = 0, clear_path_visual: bool = true) -> Array:
	var astar = astar_by_floor.get(floor_index)
	if not astar:
		return []
	
	var start_point = start.y * columns + start.x
	var end_point = end.y * columns + end.x
	path = astar.get_point_path(start_point, end_point)
	
	if clear_path_visual:
		clear_path_visualization(floor_index)

	set_cell_item(Vector3i(start.x, floor_index, start.y), start_item)
	set_cell_item(Vector3i(end.x, floor_index, end.y), end_item)
	for point in path:
		if point != start and point != end:
			set_cell_item(Vector3i(point.x, floor_index, point.y), hover_item)
	
	return path

func find_path_normal(start: Vector2, end: Vector2, floor: int = 0) -> Array:
	var s := Vector2i(start)
	var g := Vector2i(end)
	var restored: Array[Vector3i] = []

	# ---------- START ----------
	if is_inside_3x3_block(s, floor):
		s = get_3x3_centre(s, floor)
		open_3x3_neighbours(s, floor, restored)
		print("START 3×3 opened: ", restored.size(), " tiles")

	# ---------- GOAL ----------
	if is_inside_3x3_block(g, floor):
		g = get_3x3_centre(g, floor)
		open_3x3_neighbours(g, floor, restored)
		print("GOAL  3×3 opened: ", restored.size(), " tiles")

	print("restored list before graph: ", restored.size())
	initialize_astar()

	var path := _find_path_debug(Vector2(s), Vector2(g), floor)

	print("restored list after  graph: ", restored.size())
	for c in restored:
		set_cell_item(c, get_cell_item(c))
	initialize_astar()

	# append exact click coordinates for tween
	if not path.is_empty():
		if Vector2(s) != start: path.insert(0, start)
		if Vector2(g) != end:   path.append(end)
	return path

func find_path_with_snap(start: Vector2, end: Vector2, floor_index: int = 0) -> Array:
	var snapped := end
	var needs_snap := false
	var original_item := -1
	var opened_neighbors: Array[Vector2i] = []

	if is_inside_3x3_block(end, floor_index):
		snapped = get_3x3_centre(end, floor_index)
		needs_snap = true

		# 1. clear the centre
		original_item = get_cell_item(Vector3i(snapped.x, floor_index, snapped.y))
		set_cell_item(Vector3i(snapped.x, floor_index, snapped.y), normal_items[0])

		# 2. also clear the four orthogonal neighbours so A* can reach it
		for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
			var n = Vector2i(snapped) + dir
			if is_position_valid(n):
				var nid3d := Vector3i(n.x, floor_index, n.y)
				if get_cell_item(nid3d) in non_walkable_items:
					opened_neighbors.append(n)
					set_cell_item(nid3d, normal_items[0])
		
		initialize_astar()

	var path := _find_path_debug(start, snapped, floor_index)

	# restore everything
	if needs_snap:
		set_cell_item(Vector3i(snapped.x, floor_index, snapped.y), original_item)
		for n in opened_neighbors:
			set_cell_item(Vector3i(n.x, floor_index, n.y), non_walkable_items[0])
		initialize_astar()
		if not path.is_empty():
			path.append(end)

	return path

func open_diagonals_temporarily(centre: Vector2i, floor: int, restored: Array[Vector3i]):
	for d in [Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
		var dn = centre + d
		if is_position_valid(dn):
			var id3d := Vector3i(dn.x, floor, dn.y)
			if get_cell_item(id3d) in non_walkable_items:
				restored.append(id3d)
				set_cell_item(id3d, normal_items[0])

func open_3x3_neighbours(centre: Vector2i, floor: int, restored: Array[Vector3i]):
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var n := centre + Vector2i(dx, dy)
			if not is_position_valid(n): continue
			var id3d := Vector3i(n.x, floor, n.y)
			if get_cell_item(id3d) in non_walkable_items:
				restored.append(id3d)
				set_cell_item(id3d, normal_items[0])

## Return a path that *jumps* into the centre of a 3×3 block
## if the click is anywhere inside that block.
func find_path_jump(start: Vector2, end: Vector2, floor: int = 0) -> Array:
	var s := Vector2i(start)
	var g := Vector2i(end)
	var restored: Array[Vector3i] = []          # <─ declare here
	
	open_3x3_neighbours(g, floor, restored)
	
	if is_inside_3x3_block(g, floor):
		g = get_3x3_centre(g, floor)

		# 1. open centre
		var c3d := Vector3i(g.x, floor, g.y)
		var old_item := get_cell_item(c3d)
		restored.append(c3d)                    # centre will be restored later
		set_cell_item(c3d, normal_items[0])

		# 2. open the four diagonal neighbours
		open_diagonals_temporarily(g, floor, restored)   # pass the same array

		initialize_astar()

		var path := [Vector2(s), Vector2(g)]
		# 3. restore everything
		for rc in restored:
			set_cell_item(rc, get_cell_item(rc))  # put original item back
		initialize_astar()

		path.append(end)   # keep exact click for tween
		return path
	
	return find_path_with_snap(start, end, floor)

func _find_path_debug(start: Vector2, end: Vector2, floor: int) -> Array:
	# use the same AStar instance the normal find_path uses
	var astar := astar_by_floor.get(floor)
	if not astar:
		printerr("no AStar for floor ", floor)
		return []

	var start_id := int(start.y) * columns + int(start.x)
	var end_id   := int(end.y)   * columns + int(end.x)

	print("AStar ids  start: ", start_id, "  end: ", end_id)
	print("start disabled? ", astar.is_point_disabled(start_id))
	print("end   disabled? ", astar.is_point_disabled(end_id))

	var p = astar.get_point_path(start_id, end_id)
	print("raw AStar path: ", p)
	# inside _find_path_debug
	
	print("----  EDGES FROM START  ----")
	for dx in [-1,0,1]:
		for dy in [-1,0,1]:
			if dx == 0 and dy == 0: continue
			var nx = int(start.x) + dx
			var ny = int(start.y) + dy
			if nx < 0 or nx >= columns or ny < 0 or ny >= rows: continue
			var nid = ny * columns + nx
			print("  edge  ", start_id, " -> ", nid, " exists? ",
				  astar.are_points_connected(start_id, nid))
	return p

func is_inside_3x3_block(pos: Vector2, floor: int) -> bool:
	for dx in [-1,0,1]:
		for dy in [-1,0,1]:
			var n := Vector2i(pos.x + dx, pos.y + dy)
			if not is_position_valid(n): return false
			if is_cell_walkable(n, floor): return false
	print(pos, " is inside 3×3 block")
	return true

func get_3x3_centre(pos: Vector2, floor: int) -> Vector2:
	for dx in [-1,0,1]:
		for dy in [-1,0,1]:
			var n := Vector2i(pos.x + dx, pos.y + dy)
			if is_position_valid(n) and is_cell_walkable(n, floor):
				print("3×3 centre found: ", n)
				return Vector2(n)
	printerr("no walkable centre in 3×3 around ", pos)
	return pos


# Check if a position is the center of a 3x3 blue cell area
func is_3x3_center(pos: Vector2i, floor: int = 0) -> bool:
	# Check if this cell and all 8 surrounding cells are blue (item 1)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var check_pos = Vector2i(pos.x + dx, pos.y + dy)
			if not is_position_valid(check_pos):
				return false
			var cell_item = get_cell_item(Vector3i(check_pos.x, floor, check_pos.y))
			if cell_item != 1:  # Assuming 1 is the blue cell item
				return false
	return true

# Find the center of a 3x3 blue area that contains the given position
func find_3x3_center(pos: Vector2i, floor: int = 0) -> Vector2i:
	# Check all possible center positions within range
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var potential_center = Vector2i(pos.x + dx, pos.y + dy)
			if is_position_valid(potential_center) and is_3x3_center(potential_center, floor):
				return potential_center
	return Vector2i(-1, -1)  # No center found

# Check if a position is inside any 3x3 blue area
func is_inside_3x3_blue_area(pos: Vector2i, floor: int = 0) -> bool:
	return find_3x3_center(pos, floor) != Vector2i(-1, -1)

# Enhanced pathfinding that can jump into 3x3 areas
func find_path_with_3x3_jump(start: Vector2, end: Vector2, floor: int = 0) -> Array:
	var start_pos = Vector2i(start)
	var end_pos = Vector2i(end)
	
	# Check if the end position is inside a 3x3 blue area
	var end_center = find_3x3_center(end_pos, floor)
	if end_center != Vector2i(-1, -1):
		# End is in a 3x3 area, path to the center instead
		print("Target is in 3x3 area, pathfinding to center: ", end_center)
		var path_to_center = find_path(start, Vector2(end_center), floor, false)
		
		if not path_to_center.is_empty():
			# Add the original end position for smooth movement
			path_to_center.append(end)
			return path_to_center
	
	# Check if start position is inside a 3x3 blue area
	var start_center = find_3x3_center(start_pos, floor)
	if start_center != Vector2i(-1, -1):
		# Start is in a 3x3 area, begin from the center
		print("Start is in 3x3 area, pathfinding from center: ", start_center)
		var path_from_center = find_path(Vector2(start_center), end, floor, false)
		
		if not path_from_center.is_empty():
			# Insert the original start position at the beginning
			path_from_center.insert(0, start)
			return path_from_center
	
	# Neither start nor end is in 3x3 area, use regular pathfinding
	return find_path(start, end, floor, false)

# Modified neighbor detection to handle 3x3 jumping
func get_neighbors_with_3x3_jump(current_pos: Vector2i, floor_index: int) -> Array[NeighborInfo]:
	var neighbors: Array[NeighborInfo] = []
	
	# First, add regular neighbors
	neighbors.append_array(get_neighbors(current_pos, floor_index))
	
	# Then check for 3x3 jump opportunities
	var directions = {
		Direction.NORTH: Vector2i(0, -1),
		Direction.EAST: Vector2i(1, 0),
		Direction.SOUTH: Vector2i(0, 1),
		Direction.WEST: Vector2i(-1, 0)
	}
	
	# Add diagonal directions if enabled
	if diagonal_movement:
		directions[Direction.NORTHWEST] = Vector2i(-1, -1)
		directions[Direction.NORTHEAST] = Vector2i(1, -1)
		directions[Direction.SOUTHWEST] = Vector2i(-1, 1)
		directions[Direction.SOUTHEAST] = Vector2i(1, 1)
	
	# Look for 3x3 areas we can jump into
	for dir in directions:
		var offset = directions[dir]
		
		# Check positions 2 and 3 cells away for 3x3 centers
		for distance in [2, 3]:
			var jump_pos = current_pos + (offset * distance)
			if is_position_valid(jump_pos) and is_3x3_center(jump_pos, floor_index):
				# This is a 3x3 center we can jump to
				neighbors.append(NeighborInfo.new(jump_pos, dir, true, true))
				break  # Only add the closest 3x3 center in this direction
	
	return neighbors

# Enhanced A* initialization with 3x3 jumping
func initialize_astar_with_3x3():
	astar_by_floor.clear()
	for y in range(floors):
		var astar = AStar2D.new()
		
		# Add all points
		for x in range(columns):
			for z in range(rows):
				var point_id = z * columns + x
				astar.add_point(point_id, Vector2(x, z))
		
		# Connect points with enhanced neighbor detection
		for x in range(columns):
			for z in range(rows):
				var current_pos = Vector2i(x, z)
				var current_point_id = z * columns + x
				
				if not is_cell_walkable(current_pos, y):
					continue
				
				var neighbors = get_neighbors_with_3x3_jump(current_pos, y)
				
				for neighbor in neighbors:
					if neighbor.is_walkable:
						var neighbor_id = neighbor.position.y * columns + neighbor.position.x
						
						astar.disconnect_points(current_point_id, neighbor_id)
						var weight = 1.0
						
						if neighbor.is_long_jump:
							# Higher cost for jumping into 3x3 areas
							weight = 3.0
						elif is_diagonal_direction(neighbor.direction):
							weight = 1.4142
						
						astar.connect_points(current_point_id, neighbor_id, true)
						astar.set_point_weight_scale(neighbor_id, weight)
		
		astar_by_floor[y] = astar
	
	update_astar_costs()

# Helper function to create 3x3 blue areas for testing
func create_3x3_blue_area(center: Vector2i, floor: int = 0):
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var pos = Vector2i(center.x + dx, center.y + dy)
			if is_position_valid(pos):
				set_cell_item(Vector3i(pos.x, floor, pos.y), 1)  # Blue cell item
	
	# Reinitialize pathfinding to account for new 3x3 area
	initialize_astar_with_3x3()


# Path visualization
func clear_path_visualization(floor_index: int = 0):
	for x in range(columns):
		for z in range(rows):
			var cell_item = get_cell_item(Vector3i(x, floor_index, z))
			if cell_item == hover_item or cell_item == start_item or cell_item == end_item:
				set_cell_item(Vector3i(x, floor_index, z), normal_items[0])

# Cost calculation and updates
func get_cell_cost(x: int, z: int, floor_index: int = 0) -> float:
	var cell_item := get_cell_item(Vector3i(x, floor_index, z))
	if cell_item == -1 or (cell_item in non_walkable_items):
		return INF                       # completely blocked
	if cell_item == hover_item:
		return 0.5                       # fast
	if cell_item == start_item or cell_item == end_item:
		return 0.0                       # zero cost
	return 1.0                           # normal terrain

func update_astar_costs():
	for floor_index in range(floors):
		var astar = astar_by_floor.get(floor_index)
		if astar:
			for x in range(columns):
				for z in range(rows):
					var point_id = z * columns + x
					var cost = get_cell_cost(x, z, floor_index)
					if cost == INF:
						astar.set_point_disabled(point_id, true)
					else:
						astar.set_point_disabled(point_id, false)
						astar.set_point_weight_scale(point_id, cost)

# Grid data management
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

# Check the obstacle on a cell
func has_obstacle_at(pos: Vector3i) -> bool:
	var item = get_cell_item(pos)
	return item in obstacle_items

# Get orientation ( rotation )
func get_cell_orientation(pos: Vector3i) -> int:
	return get_cell_item_orientation(pos)

# Get obstacle direction
# Get the direction of an obstacle at a specific position
func get_obstacle_direction(pos: Vector3i) -> Direction:
	if obstacle_directions.has(pos):
		return obstacle_directions[pos]
	return Direction.CENTER

func get_obstacle_orientation(pos: Vector3i) -> int:
	return get_cell_item_orientation(pos)

func is_movement_blocked(from_pos: Vector2i, to_pos: Vector2i, floor_index: int = 3) -> bool:
	# Must be adjacent cells for direct blocking check
	if abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y) != 1:
		return false
	
	# Get 3D positions for the cells
	var from_pos3d = Vector3i(from_pos.x, floor_index, from_pos.y)
	var to_pos3d = Vector3i(to_pos.x, floor_index, to_pos.y)
	
	# Check if the starting cell has an obstacle
	if has_obstacle_at(from_pos3d):
		var orientation = get_obstacle_orientation(from_pos3d)
		
		# Check if the obstacle is blocking the requested movement direction
		if from_pos.y > to_pos.y and orientation == 0:  # Moving NORTH, obstacle faces NORTH
			return true
		elif from_pos.x < to_pos.x and orientation == 1:  # Moving EAST, obstacle faces EAST
			return true
		elif from_pos.y < to_pos.y and orientation == 2:  # Moving SOUTH, obstacle faces SOUTH
			return true
		elif from_pos.x > to_pos.x and orientation == 3:  # Moving WEST, obstacle faces WEST
			return true
	
	# Check if the destination cell has an obstacle blocking entry
	if has_obstacle_at(to_pos3d):
		var orientation = get_obstacle_orientation(to_pos3d)
		
		# Check if the obstacle is blocking entry from the requested direction
		if to_pos.y < from_pos.y and orientation == 2:  # Coming from SOUTH, obstacle faces SOUTH
			return true
		elif to_pos.x > from_pos.x and orientation == 3:  # Coming from WEST, obstacle faces WEST
			return true
		elif to_pos.y > from_pos.y and orientation == 0:  # Coming from NORTH, obstacle faces NORTH
			return true
		elif to_pos.x < from_pos.x and orientation == 1:  # Coming from EAST, obstacle faces EAST
			return true
	
	return false

# Function to check if a cell is blocked by any obstacles in its vicinity
func is_cell_blocked_by_obstacles(pos: Vector2i, floor_index: int = 3) -> bool:
	var pos3d = Vector3i(pos.x, floor_index, pos.y)
	
	# Check if this cell itself has an obstacle
	if has_obstacle_at(pos3d):
		return true
	
	# Check all adjacent cells for obstacles that might block this cell
	var adjacent_positions = [
		Vector2i(pos.x, pos.y - 1),  # North
		Vector2i(pos.x + 1, pos.y),  # East
		Vector2i(pos.x, pos.y + 1),  # South
		Vector2i(pos.x - 1, pos.y),  # West
	]
	
	for adj_pos in adjacent_positions:
		var adj_pos3d = Vector3i(adj_pos.x, floor_index, adj_pos.y)
		
		# Check if position is valid
		if is_position_valid(adj_pos) and has_obstacle_at(adj_pos3d):
			var orientation = get_obstacle_orientation(adj_pos3d)
			
			# Check if the obstacle is blocking this cell
			if adj_pos.y < pos.y and orientation == 0:  # Obstacle to NORTH facing NORTH
				return true
			elif adj_pos.x > pos.x and orientation == 1:  # Obstacle to EAST facing EAST
				return true
			elif adj_pos.y > pos.y and orientation == 2:  # Obstacle to SOUTH facing SOUTH
				return true
			elif adj_pos.x < pos.x and orientation == 3:  # Obstacle to WEST facing WEST
				return true
	
	return false

# Function to get all cells blocked by an obstacle at a specific position
func get_cells_blocked_by_obstacle(obstacle_pos: Vector2i, orientation: int, floor_index: int = 3) -> Array:
	var blocked_cells = []
	
	# Determine which cells are blocked based on orientation
	match orientation:
		0:  # NORTH - blocks the row above
			for x in range(max(0, obstacle_pos.x - 1), min(columns, obstacle_pos.x + 2)):
				blocked_cells.append(Vector2i(x, obstacle_pos.y - 1))
		
		1:  # EAST - blocks the column to the right
			for y in range(max(0, obstacle_pos.y - 1), min(rows, obstacle_pos.y + 2)):
				blocked_cells.append(Vector2i(obstacle_pos.x + 1, y))
		
		2:  # SOUTH - blocks the row below
			for x in range(max(0, obstacle_pos.x - 1), min(columns, obstacle_pos.x + 2)):
				blocked_cells.append(Vector2i(x, obstacle_pos.y + 1))
		
		3:  # WEST - blocks the column to the left
			for y in range(max(0, obstacle_pos.y - 1), min(rows, obstacle_pos.y + 2)):
				blocked_cells.append(Vector2i(obstacle_pos.x - 1, y))
	
	# Filter out invalid positions
	return blocked_cells.filter(func(pos): return is_position_valid(pos))

# Cell rotation handling
func get_cell_rotation(position: Vector3i) -> int:
	return get_cell_item_orientation(position)

func set_cell_rotation(position: Vector3i, mode: int):
	var item = get_cell_item(position)
	if item != -1:
		set_cell_item(position, item, mode)

# Mesh library handling
func _on_mesh_library_changed():
	validate_item_indices()
	if auto_generate:
		generate_grid()
		_update_cell_option_buttons()

func _update_cell_option_buttons():
	if not mesh_library:
		return

	var item_list = mesh_library.get_item_list()

	for x in range(columns):
		for z in range(rows):
			var position = Vector3i(x, 0, z)
			var cell_item = get_cell_item(position)
			if cell_item != -1 and cell_item < item_list.size():
				set_cell_item(position, cell_item)
			else:
				set_cell_item(position, 0)

func _set(property, value):
	if property == "mesh_library":
		mesh_library = value
		_on_mesh_library_changed()
		return true
	return false

# Toggle diagonal movement
func set_diagonal_movement(enable: bool):
	diagonal_movement = enable
	initialize_astar()

func is_blocked_by_obstacle(from_pos: Vector2i, to_pos: Vector2i, floor_index: int = 3) -> bool:
	# For direct orthogonal movement (up, down, left, right)
	if (from_pos.x == to_pos.x and abs(from_pos.y - to_pos.y) == 1) or (from_pos.y == to_pos.y and abs(from_pos.x - to_pos.x) == 1):
		return is_movement_blocked(from_pos, to_pos, floor_index)
	
	# For diagonal or longer distances, build a path and check each step
	var path = []
	
	# Simple path planning for orthogonal movement
	if from_pos.x == to_pos.x or from_pos.y == to_pos.y:
		var dx = sign(to_pos.x - from_pos.x)
		var dy = sign(to_pos.y - from_pos.y)
		var current = from_pos
		
		while current != to_pos:
			var next = Vector2i(current.x + dx, current.y + dy)
			path.append([current, next])
			current = next
	else:
		# For diagonal movement, check both possible paths
		# Path 1: Move horizontally first, then vertically
		var mid1 = Vector2i(to_pos.x, from_pos.y)
		var path1_blocked = is_blocked_by_obstacle(from_pos, mid1, floor_index) or is_blocked_by_obstacle(mid1, to_pos, floor_index)
		
		# Path 2: Move vertically first, then horizontally
		var mid2 = Vector2i(from_pos.x, to_pos.y)
		var path2_blocked = is_blocked_by_obstacle(from_pos, mid2, floor_index) or is_blocked_by_obstacle(mid2, to_pos, floor_index)
		
		# Movement is blocked if both paths are blocked
		return path1_blocked and path2_blocked
	
	# Check each step in the path
	for step in path:
		if is_movement_blocked(step[0], step[1], floor_index):
			return true
	
	return false

# Place an obstacle at the specified position with a specific orientation
func place_obstacle(pos: Vector3i, obstacle_item: int, orientation: int) -> bool:
	# Always place on floor 3
	pos.y = 3
	
	if get_cell_item(pos) != -1:
		return false  # Cell is already occupied
	
	# Set the obstacle item with the specified orientation
	set_cell_item(pos, obstacle_item, orientation)
	
	# Store the obstacle information
	obstacles[pos] = orientation
	
	# Re-initialize A* pathfinding to account for the new obstacle
	initialize_astar()
	
	return true
