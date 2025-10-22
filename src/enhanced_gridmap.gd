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

func _ready():
	if auto_generate:
		generate_grid(0)

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
