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
@onready var grid_container = $VBoxContainer/GridScrollContainer/GridContainer

# A* Pathfinding UI elements
@onready var start_x_spin = $VBoxContainer/AStarContainer/StartX/SpinBox
@onready var start_z_spin = $VBoxContainer/AStarContainer/StartZ/SpinBox
@onready var end_x_spin = $VBoxContainer/AStarContainer/EndX/SpinBox
@onready var end_z_spin = $VBoxContainer/AStarContainer/EndZ/SpinBox
@onready var find_path_button = $VBoxContainer/AStarContainer/FindPathButton
@onready var path_result_label = $VBoxContainer/AStarContainer/PathResultLabel
@onready var diagonal_movement_check = $VBoxContainer/AStarContainer/DiagonalMovement

# Item state UI elements
@onready var normal_item_spin = $VBoxContainer/ItemStates/NormalItem/SpinBox
@onready var hover_item_spin = $VBoxContainer/ItemStates/HoverItem/SpinBox
@onready var start_item_spin = $VBoxContainer/ItemStates/StartItem/SpinBox
@onready var end_item_spin = $VBoxContainer/ItemStates/EndItem/SpinBox
@onready var non_walkable_item_spin = $VBoxContainer/ItemStates/NonWalkableItem/SpinBox
# Custom item states UI elements
@onready var item_states_container = $VBoxContainer/ItemStates/ItemStatesContainer
@onready var add_item_state_button = $VBoxContainer/ItemStates/AddItemStateButton

var row_containers: Array = []
var cell_options: Array = []
var custom_item_states: Dictionary = {}

func _ready():
	connect_signals()
	initialize_custom_item_states()
	print("EnhancedGridMapDock ready")

func connect_signals():
	columns_spin.value_changed.connect(_on_columns_changed)
	rows_spin.value_changed.connect(_on_rows_changed)
	auto_generate_check.toggled.connect(_on_auto_generate_toggled)
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	fill_button.pressed.connect(_on_fill_pressed)
	find_path_button.pressed.connect(_on_find_path_pressed)
	diagonal_movement_check.toggled.connect(_on_diagonal_movement_toggled)
	add_item_state_button.pressed.connect(_on_add_item_state_pressed)
	normal_item_spin.value_changed.connect(_on_normal_item_changed)
	hover_item_spin.value_changed.connect(_on_hover_item_changed)
	start_item_spin.value_changed.connect(_on_start_item_changed)
	end_item_spin.value_changed.connect(_on_end_item_changed)
	non_walkable_item_spin.value_changed.connect(_on_non_walkable_item_changed)

func initialize_custom_item_states():
	# Add default item states
	add_custom_item_state("Normal", 0)
	#add_custom_item_state("Hover", 1)
	#add_custom_item_state("Start", 2)
	#add_custom_item_state("End", 3)
	add_custom_item_state("Non-Walkable", 4)

func add_custom_item_state(name: String, id: int):
	var new_state = CustomItemState.new(name, id)
	custom_item_states[id] = new_state
	add_item_state_ui(new_state)

func add_item_state_ui(item_state: CustomItemState):
	var container = HBoxContainer.new()
	var name_edit = LineEdit.new()
	var id_spin = SpinBox.new()
	var randomize_check = CheckBox.new()
	var percentage_spin = SpinBox.new()
	var remove_button = Button.new()

	name_edit.text = item_state.name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_item_state_name_changed.bind(item_state))

	id_spin.value = item_state.id
	id_spin.min_value = 0
	id_spin.max_value = 9999
	id_spin.value_changed.connect(_on_item_state_id_changed.bind(item_state))

	randomize_check.text = "🎲"
	randomize_check.button_pressed = item_state.include_in_randomize  # Changed from 'pressed' to 'button_pressed'
	randomize_check.toggled.connect(_on_item_state_randomize_toggled.bind(item_state))

	percentage_spin.min_value = 0
	percentage_spin.max_value = 100
	percentage_spin.value = item_state.randomize_percentage
	percentage_spin.suffix = "%"
	percentage_spin.value_changed.connect(_on_item_state_percentage_changed.bind(item_state))

	remove_button.text = "Del"
	remove_button.pressed.connect(_on_remove_item_state_pressed.bind(item_state, container))

	container.add_child(name_edit)
	container.add_child(id_spin)
	container.add_child(randomize_check)
	container.add_child(percentage_spin)
	container.add_child(remove_button)

	item_states_container.add_child(container)

func _on_add_item_state_pressed():
	var new_id = custom_item_states.size()
	add_custom_item_state("New State {0}".format([new_id]), new_id)

func _on_item_state_name_changed(new_name: String, item_state: CustomItemState):
	item_state.name = new_name

func _on_item_state_id_changed(new_id: int, item_state: CustomItemState):
	custom_item_states.erase(item_state.id)
	item_state.id = new_id
	custom_item_states[new_id] = item_state

func _on_item_state_randomize_toggled(toggled: bool, item_state: CustomItemState):
	item_state.include_in_randomize = toggled

func _on_item_state_percentage_changed(new_percentage: float, item_state: CustomItemState):
	item_state.randomize_percentage = new_percentage

func _on_remove_item_state_pressed(item_state: CustomItemState, container: Container):
	custom_item_states.erase(item_state.id)
	container.queue_free()

class CustomItemState:
	var name: String
	var id: int
	var include_in_randomize: bool = false
	var randomize_percentage: float = 0

	func _init(_name: String, _id: int):
		name = _name
		id = _id

func set_enhanced_gridmap(gridmap: EnhancedGridMap):
	enhanced_gridmap = gridmap
	enhanced_gridmap.grid_updated.connect(_on_grid_updated)
	update_ui()
	diagonal_movement_check.button_pressed = enhanced_gridmap.diagonal_movement
	print("EnhancedGridMap set: ", enhanced_gridmap)

func update_ui():
	if enhanced_gridmap:
		columns_spin.value = enhanced_gridmap.columns
		rows_spin.value = enhanced_gridmap.rows
		auto_generate_check.button_pressed = enhanced_gridmap.auto_generate
		_update_fill_options()
		_update_grid_ui()
		_update_astar_ui()
		_update_item_state_ui()
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
			var cell_container = VBoxContainer.new()
			cell_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			var coord_label = Label.new()
			coord_label.text = "(%d,%d)" % [x, z]
			coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			coord_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			coord_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell_container.add_child(coord_label)

			var option = OptionButton.new()
			option.set_meta("grid_position", Vector2i(x, z))
			for i in range(item_list.size()):
				option.add_item(enhanced_gridmap.mesh_library.get_item_name(item_list[i]), i)
			var cell_item = enhanced_gridmap.get_cell_item(Vector3i(x, 0, z))
			option.select(cell_item)
			option.item_selected.connect(_on_cell_item_selected.bind(option))
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell_container.add_child(option)

			# Add rotation Option for each cell
			var rotation_option = OptionButton.new()
			rotation_option.add_item("0°", 0)
			rotation_option.add_item("90°", 10)
			rotation_option.add_item("180°", 16)
			rotation_option.add_item("270°", 22)
			rotation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rotation_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rotation_option.set_meta("grid_position", Vector2i(x, z))
			# Set the current item based on the cell's rotation
			var current_rotation = enhanced_gridmap.get_cell_rotation(Vector3i(x, 0, z))
			match current_rotation:
				0: rotation_option.select(0)
				10: rotation_option.select(1)
				16: rotation_option.select(2)
				22: rotation_option.select(3)
			rotation_option.item_selected.connect(_on_cell_rotation_changed.bind(rotation_option))
			
			cell_container.add_child(rotation_option)
			
			row_container.add_child(cell_container)
			cell_options.append(option)

	print("Grid UI updated. Total cells: ", cell_options.size())

func _update_astar_ui():
	start_x_spin.max_value = enhanced_gridmap.columns - 1
	start_z_spin.max_value = enhanced_gridmap.rows - 1
	end_x_spin.max_value = enhanced_gridmap.columns - 1
	end_z_spin.max_value = enhanced_gridmap.rows - 1

func _update_item_state_ui():
	normal_item_spin.value = enhanced_gridmap.normal_item
	hover_item_spin.value = enhanced_gridmap.hover_item
	start_item_spin.value = enhanced_gridmap.start_item
	end_item_spin.value = enhanced_gridmap.end_item
	non_walkable_item_spin.value = enhanced_gridmap.non_walkable_item

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
		var randomize_states = []
		var total_percentage = 0
		for state in custom_item_states.values():
			if state.include_in_randomize:
				randomize_states.append(state)
				total_percentage += state.randomize_percentage

		if total_percentage != 100:
			print("Warning: Total randomize percentage is not 100%")

		enhanced_gridmap.randomize_grid_custom(randomize_states)

func _on_fill_pressed():
	if enhanced_gridmap:
		var selected_index = fill_options.get_selected_id()
		enhanced_gridmap.fill_grid(selected_index)
		print("Fill grid pressed with item index: ", selected_index)

func _on_cell_item_selected(index: int, option: OptionButton):
	var position = option.get_meta("grid_position")
	if enhanced_gridmap:
		enhanced_gridmap.set_cell_from_data(position.x, position.y, index)
		print("Cell item selected: ", index, " at position: ", position)

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

func _on_diagonal_movement_toggled(button_pressed):
	if enhanced_gridmap:
		enhanced_gridmap.set_diagonal_movement(button_pressed)
		print("Diagonal movement toggled: ", button_pressed)

func _on_normal_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.normal_item = value
		print("Normal item changed to: ", value)

func _on_hover_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.hover_item = value
		print("Hover item changed to: ", value)

func _on_start_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.start_item = value
		print("Start item changed to: ", value)

func _on_end_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.end_item = value
		print("End item changed to: ", value)

func _on_non_walkable_item_changed(value):
	if enhanced_gridmap:
		enhanced_gridmap.non_walkable_item = value
		print("Non-walkable item changed to: ", value)

func _on_grid_updated():
	update_ui()

func _on_cell_rotation_changed(index: int, option: OptionButton):
	var position = option.get_meta("grid_position")
	var rotation_value = option.get_item_id(index)
	if enhanced_gridmap:
		enhanced_gridmap.set_cell_rotation(Vector3i(position.x, 0, position.y), rotation_value)
		print("Cell rotation changed: ", rotation_value, " at position: ", position)
