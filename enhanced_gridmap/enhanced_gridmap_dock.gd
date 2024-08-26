@tool
extends Control

var enhanced_gridmap: EnhancedGridMap

@onready var columns_spin = $VBoxContainer/Columns/SpinBox
@onready var rows_spin = $VBoxContainer/Rows/SpinBox
@onready var auto_generate_check = $VBoxContainer/AutoGenerate
@onready var generate_button = $VBoxContainer/GenerateButton
@onready var clear_button = $VBoxContainer/ClearButton
@onready var randomize_button = $VBoxContainer/RandomizeButton
@onready var fill_options = $VBoxContainer/FillOptions
@onready var fill_button = $VBoxContainer/FillButton
@onready var grid_container = $VBoxContainer/ScrollContainer/GridContainer

# New A* Pathfinding UI elements
@onready var start_x_spin = $VBoxContainer/AStarContainer/StartX/SpinBox
@onready var start_z_spin = $VBoxContainer/AStarContainer/StartZ/SpinBox
@onready var end_x_spin = $VBoxContainer/AStarContainer/EndX/SpinBox
@onready var end_z_spin = $VBoxContainer/AStarContainer/EndZ/SpinBox
@onready var find_path_button = $VBoxContainer/AStarContainer/FindPathButton
@onready var path_result_label = $VBoxContainer/AStarContainer/PathResultLabel

# Item state UI elements
@onready var normal_item_spin = $VBoxContainer/ItemStates/NormalItem/SpinBox
@onready var hover_item_spin = $VBoxContainer/ItemStates/HoverItem/SpinBox
@onready var start_item_spin = $VBoxContainer/ItemStates/StartItem/SpinBox
@onready var end_item_spin = $VBoxContainer/ItemStates/EndItem/SpinBox
@onready var non_walkable_item_spin = $VBoxContainer/ItemStates/NonWalkableItem/SpinBox

var row_containers: Array = []
var cell_options: Array = []

func _ready():
	columns_spin.value_changed.connect(_on_columns_changed)
	rows_spin.value_changed.connect(_on_rows_changed)
	auto_generate_check.toggled.connect(_on_auto_generate_toggled)
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	fill_button.pressed.connect(_on_fill_pressed)
	
	# Connect A* Pathfinding UI elements
	find_path_button.pressed.connect(_on_find_path_pressed)
	
	# Connect Item State UI elements
	normal_item_spin.value_changed.connect(_on_normal_item_changed)
	hover_item_spin.value_changed.connect(_on_hover_item_changed)
	start_item_spin.value_changed.connect(_on_start_item_changed)
	end_item_spin.value_changed.connect(_on_end_item_changed)
	non_walkable_item_spin.value_changed.connect(_on_non_walkable_item_changed)
	
	print("EnhancedGridMapDock ready")

func set_enhanced_gridmap(gridmap: EnhancedGridMap):
	enhanced_gridmap = gridmap
	enhanced_gridmap.grid_updated.connect(_on_grid_updated)
	update_ui()
	
	# Debug print
	print("EnhancedGridMap set: ", enhanced_gridmap)

func update_ui():
	if enhanced_gridmap:
		columns_spin.value = enhanced_gridmap.columns
		rows_spin.value = enhanced_gridmap.rows
		auto_generate_check.button_pressed = enhanced_gridmap.auto_generate
		_update_fill_options()
		_update_grid_ui()
		
		# Update A* Pathfinding UI elements
		start_x_spin.max_value = enhanced_gridmap.columns - 1
		start_z_spin.max_value = enhanced_gridmap.rows - 1
		end_x_spin.max_value = enhanced_gridmap.columns - 1
		end_z_spin.max_value = enhanced_gridmap.rows - 1
		
		# Update Item State UI elements
		normal_item_spin.value = enhanced_gridmap.normal_item
		hover_item_spin.value = enhanced_gridmap.hover_item
		start_item_spin.value = enhanced_gridmap.start_item
		end_item_spin.value = enhanced_gridmap.end_item
		non_walkable_item_spin.value = enhanced_gridmap.non_walkable_item
		
		print("UI updated. Columns: ", enhanced_gridmap.columns, " Rows: ", enhanced_gridmap.rows)

func _update_fill_options():
	fill_options.clear()
	if enhanced_gridmap and enhanced_gridmap.mesh_library:
		var item_list = enhanced_gridmap.mesh_library.get_item_list()
		for i in range(item_list.size()):
			fill_options.add_item(enhanced_gridmap.mesh_library.get_item_name(item_list[i]), i)

func _update_grid_ui():
	for child in grid_container.get_children():
		child.queue_free()
	row_containers.clear()
	cell_options.clear()

	if not enhanced_gridmap or not enhanced_gridmap.mesh_library:
		print("No EnhancedGridMap or MeshLibrary")
		return

	var item_list = enhanced_gridmap.mesh_library.get_item_list()
	
	print("Updating grid UI. Columns: ", enhanced_gridmap.columns, " Rows: ", enhanced_gridmap.rows)

	for z in range(enhanced_gridmap.rows):
		var row_container = HBoxContainer.new()
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.add_child(row_container)
		row_containers.append(row_container)

		for x in range(enhanced_gridmap.columns):
			var option = OptionButton.new()
			option.set_meta("grid_position", Vector2i(x, z))
			for i in range(item_list.size()):
				option.add_item(enhanced_gridmap.mesh_library.get_item_name(item_list[i]), i)
			var cell_item = enhanced_gridmap.get_cell_item(Vector3i(x, 0, z))
			option.select(cell_item)
			option.item_selected.connect(_on_cell_item_selected.bind(option))
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_container.add_child(option)
			cell_options.append(option)

	print("Grid UI updated. Total cells: ", cell_options.size())

func _on_columns_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.columns = value
		print("Columns changed to: ", value)

func _on_rows_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.rows = value
		print("Rows changed to: ", value)

func _on_auto_generate_toggled(button_pressed):
	if enhanced_gridmap:
		enhanced_gridmap.auto_generate = button_pressed

func _on_generate_pressed():
	if enhanced_gridmap:
		enhanced_gridmap.generate_grid()
		print("Generate grid pressed")

func _on_clear_pressed():
	if enhanced_gridmap:
		enhanced_gridmap.clear_grid()
		print("Clear grid pressed")

func _on_randomize_pressed():
	if enhanced_gridmap:
		enhanced_gridmap.randomize_grid()
		_update_grid_ui()
		print("Grid randomized")

func _on_fill_pressed():
	if enhanced_gridmap:
		var selected_index = fill_options.get_selected_id()
		if selected_index >= 0:
			enhanced_gridmap.fill_grid(selected_index)
		print("Fill grid pressed with index: ", selected_index)

func _on_grid_updated():
	_update_grid_ui()
	print("Grid updated signal received")

func _on_cell_item_selected(index: int, option: OptionButton):
	var grid_position = option.get_meta("grid_position")
	enhanced_gridmap.set_cell_from_data(grid_position.x, grid_position.y, index)
	#enhanced_gridmap.update_astar_costs()  # Update A* costs when cell changes
	print("Cell selected: ", grid_position, " with index: ", index)

func _on_find_path_pressed():
	if enhanced_gridmap:
		var start = Vector2(start_x_spin.value, start_z_spin.value)
		var end = Vector2(end_x_spin.value, end_z_spin.value)
		var path = enhanced_gridmap.find_path(start, end)
		if path.is_empty():
			path_result_label.text = "No path found"
		else:
			path_result_label.text = "Path found: " + str(path)
		print("Find path pressed. Start: ", start, " End: ", end)
		_update_grid_ui()  # Update the grid UI to reflect the changes

func _on_normal_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.normal_item = value
		_update_grid_ui()

func _on_hover_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.hover_item = value
		_update_grid_ui()

func _on_start_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.start_item = value
		_update_grid_ui()

func _on_end_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.end_item = value
		_update_grid_ui()

func _on_non_walkable_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.non_walkable_item = value
		_update_grid_ui()
		enhanced_gridmap.update_astar_costs()
