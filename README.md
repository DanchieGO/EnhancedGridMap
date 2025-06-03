# EnhancedGridMap Plugin for Godot 4.4.1

## Overview

EnhancedGridMap is a powerful plugin for Godot 4.3 that extends the functionality of the built-in GridMap node. It provides additional features for grid-based game development, including custom cell states, multi-floor support, and advanced grid manipulation tools.

## Features

- Custom grid size (columns and rows)
- Multi-floor support with floor management
- Auto-generation of grid
- Custom cell states with visual representation
- A* pathfinding with diagonal movement option
- Randomization of grid cells
- Fill grid with specific cell types
- Item swapping functionality
- Editor dock for easy manipulation of grid properties
- Floor-specific operations for generating, clearing, and filling grids

## Installation

1. Copy the `enhanced_gridmap` folder into your Godot project's `addons` directory.
2. Enable the plugin in Project Settings > Plugins.

## EnhancedGridMap Dock

The EnhancedGridMap Dock provides a user-friendly interface to control and manipulate the EnhancedGridMap node. Here's a detailed explanation of all features available in the dock:

### Grid Properties

1. **Columns**: Set the number of columns in the grid.
2. **Rows**: Set the number of rows in the grid.
3. **Floors**: Set the number of floors in your grid.
4. **Current Floor**: Select which floor to edit.
5. **Auto Generate**: Toggle automatic grid generation when properties change.

### Grid Operations

1. **Generate**: Manually generate the grid based on current properties.
2. **Clear**: Remove all cells from the grid.
3. **Randomize**: Randomly assign cell types based on defined states.
4. **Fill**: Fill the entire grid with a specific cell type.
5. **Swap Items**: Replace all instances of one item type with another.

### Cell States

The dock allows you to define and manage custom cell states:

1. **Default States**:
   - Normal
   - Hover
   - Start
   - End
   - Non-Walkable

2. **Custom States**:
   - Add new states with the "Add Item State" button.
   - For each state, you can set:
     - Name
     - ID (used in scripts to reference the state)
     - Include in Randomize (toggle)
     - Randomize Percentage (when included in randomization)

3. **State Management**:
   - Edit existing states
   - Remove custom states
   - Swap items between states

### Floor Management

The new floor management system allows you to:

1. **Add/Remove Floors**: Dynamically adjust the number of floors in your grid.
2. **Floor Navigation**: Easily switch between different floors for editing.
3. **Floor-Specific Operations**:
   - Generate specific floors
   - Clear individual floors
   - Fill selected floors with specific items

### Item Swapping

The new item swapping feature allows you to:

1. **Select Source Item**: Choose the item type to be replaced.
2. **Select Target Item**: Choose the new item type to replace with.
3. **Swap Items**: Replace all instances of the source item with the target item.
4. **Floor-Specific Swapping**: Option to swap items only on the current floor or across all floors.

### A* Pathfinding

1. **Start Position**: Set the X and Z coordinates for the pathfinding start point.
2. **End Position**: Set the X and Z coordinates for the pathfinding end point.
3. **Find Path**: Calculate and visualize the path between start and end points.
4. **Diagonal Movement**: Toggle to allow diagonal movement in pathfinding.

### Visual Grid Editor

The dock includes a visual representation of the grid:

1. Each cell displays its coordinates.
2. Drop-down menus in each cell allow you to change the cell's state directly.

## In-Depth Feature Explanation

### Custom Grid Generation

The EnhancedGridMap allows for flexible grid generation:

1. **Auto-generation**: The grid can automatically update when properties change.
2. **Manual generation**: Use the `generate_grid()` method for custom generation logic.
3. **Clear and regenerate**: Useful for level resets or procedural generation.

### Cell States

Cell states are central to the EnhancedGridMap's functionality:

1. **Default states**: Predefined states for common use cases (normal, hover, start, end, non-walkable).
2. **Custom states**: Create states for specific game mechanics (e.g., water, lava, ice).
3. **State properties**:
   - ID: Used in scripts to set or check cell states.
   - Name: Human-readable label
   - Randomize inclusion: Determine if the state should be included in randomization.
   - Randomize percentage: Control the frequency of the state when randomizing.

### A* Pathfinding

The integrated A* pathfinding system offers:

1. **Efficient pathfinding**: Quickly find optimal paths between two points.
2. **Diagonal movement**: Option to allow or disallow diagonal movement.
3. **Custom cost functions**: Override `get_cell_cost()` for complex movement rules.
4. **Path visualization**: Easily visualize calculated paths for debugging.

### Grid Manipulation

Several methods for manipulating the grid:

1. **`set_cell_from_data(x, z, item_index)`**: Set a specific cell's state.
2. **`fill_grid(item_index)`**: Fill the entire grid with a specific state.
3. **`randomize_grid()`**: Randomly assign states based on defined probabilities.
4. **`randomize_grid_custom(randomize_states)`**: Use custom randomization rules.

### Extending Functionality

The EnhancedGridMap is designed to be easily extended:

1. **Custom grid generation**: Override `generate_grid()` for specialized layouts.
2. **Custom pathfinding costs**: Implement `get_cell_cost()` for complex movement rules.
3. **Integration with game mechanics**: Use signals like `grid_updated` to trigger game events.

### Editor Integration

The plugin seamlessly integrates with the Godot editor:

1. **Visual editing**: Manipulate the grid directly in the editor viewport.
2. **Real-time updates**: Changes in the dock immediately reflect in the scene.
3. **Custom inspector**: The EnhancedGridMap node has a custom inspector for easy property editing.

## Plugin Usage

### Basic Setup

1. Add an `EnhancedGridMap` node to your scene.
2. Assign a `MeshLibrary` to the `EnhancedGridMap`.
3. Use the `EnhancedGridMap` dock in the editor to configure grid properties and cell states.

### Scripting

You can also interact with the `EnhancedGridMap` through GDScript. Here's a basic example:

```gdscript
var enhanced_gridmap = $EnhancedGridMap

# Generate a 10x10 grid
enhanced_gridmap.columns = 10
enhanced_gridmap.rows = 10
enhanced_gridmap.generate_grid()

# Find a path from (0,0) to (5,5)
var path = enhanced_gridmap.find_path(Vector2(0, 0), Vector2(5, 5))
```

## Sample Scene and Player Movement

The plugin includes a sample scene that demonstrates how to implement player movement using the EnhancedGridMap. This scene showcases pathfinding and grid-based movement.

### Scene Setup

The sample scene (`main.tscn`) includes:

1. An `EnhancedGridMap` node with a pre-configured grid.
2. A player character `CharacterBody3D` with a custom script for grid-based movement.
3. A top-down camera for easy visualization.

### Player Movement Script

The `player.gd` script provides a flexible implementation of grid-based movement using the EnhancedGridMap. Key features include:

- Click-to-move functionality
- Pathfinding using the EnhancedGridMap's A* algorithm
- Smooth movement along the calculated path
- Customizable cell size and offset
- Option for diagonal movement

### Usage Example

To use the player movement script in your own scene:

1. Add an `EnhancedGridMap` to your scene.
2. Add a `CharacterBody3D` (or other suitable node) for your player.
3. Attach the `player.gd` script to your player node.
4. Set the `enhanced_gridmap_path` and `player_path` in the inspector.
5. Customize other properties like `cell_size` and `use_diagonal_movement` as needed.

Here's a minimal setup example:

```gdscript
extends Node3D

@onready var enhanced_gridmap = $EnhancedGridMap
@onready var player = $Player

func _ready():
    player.enhanced_gridmap_path = enhanced_gridmap.get_path()
    player.player_path = player.get_path()
    player.cell_size = Vector3(2, 2, 2)
    player.use_diagonal_movement = true
```

This setup allows for click-to-move functionality on your EnhancedGridMap, with the player finding and following optimal paths while avoiding non-walkable cells.

## API Reference

### Properties

- `columns: int` - Number of columns in the grid
- `rows: int` - Number of rows in the grid
- `auto_generate: bool` - Whether to automatically generate the grid when properties change
- `normal_items: Array[int]` - Array of item indices for normal cells (default: [0])
- `non_walkable_items: Array[int]` - Array of item indices for non-walkable cells (default: [4])
- `hover_item: int` - Item index for hover state cells
- `start_item: int` - Item index for pathfinding start cells
- `end_item: int` - Item index for pathfinding end cells
- `non_walkable_item: int` - Item index for non-walkable cells
- `diagonal_movement: bool` - Whether to allow diagonal movement in pathfinding

### Methods

#### Grid Management

- `generate_grid()` - Generate the grid based on current properties
- `clear_grid()` - Clear all cells in the grid
- `randomize_grid()` - Randomize cell types in the grid
- `randomize_grid_custom(randomize_states: Array)` - Randomize cell types based on custom states
- `fill_grid(item_index: int)` - Fill the entire grid with a specific item type
- `validate_item_indices()` - Validate and ensure all item indices are within valid range

#### Property Setters

- `set_columns(value: int)` - Set the number of columns and update grid if auto-generate is enabled
- `set_rows(value: int)` - Set the number of rows and update grid if auto-generate is enabled
- `set_floors(value: int)` - Set the number of floors and update grid if auto-generate is enabled
- `set_auto_generate(value: bool)` - Enable/disable auto-generation of grid on property changes

#### Cell Manipulation

- `set_cell_from_data(x: int, z: int, item_index: int)` - Set a specific cell's item type
- `get_cell_cost(x: int, z: int) -> float` - Get the cost of moving through a specific cell
- `update_grid_data()` - Update the internal grid data structure
- `update_cell_visual(x: int, z: int)` - Update the visual representation of a specific cell

#### Pathfinding

- `find_path(start: Vector2, end: Vector2) -> Array` - Find a path between two points
- `set_diagonal_movement(enable: bool)` - Enable or disable diagonal movement in pathfinding
- `set_point_solid(x: int, z: int, is_solid: bool)` - Set whether a point is solid (non-walkable) for pathfinding
- `initialize_astar()` - Initialize the A* pathfinding system
- `update_astar_costs()` - Update pathfinding costs for all cells

### Signals

- `mesh_library_changed` - Emitted when the MeshLibrary is changed
- `grid_updated` - Emitted when the grid is updated

### Internal Variables

- `current_mesh_library: MeshLibrary` - Reference to the currently assigned MeshLibrary
- `grid_data: Array` - 3D array storing grid data [floor][row][column]
- `astar_by_floor: Dictionary` - Dictionary of AStar2D instances per floor
- `path: Array` - Stores the last calculated pathfinding path

### Example Scene : Player Movement API

Here are the main properties and methods of the player movement script:

#### Properties

- `enhanced_gridmap_path: NodePath` - Path to the EnhancedGridMap node
- `player_path: NodePath` - Path to the player node
- `cell_size: Vector3` - Size of each grid cell
- `cell_offset: Vector3` - Offset applied to the player's position
- `center_x: bool` - Center the player horizontally within the cell
- `center_y: bool` - Center the player vertically within the cell
- `center_z: bool` - Center the player depth-wise within the cell
- `use_diagonal_movement: bool` - Allow diagonal movement in pathfinding

#### Methods

- `find_valid_starting_position() -> Vector2i` - Find a valid starting position on the grid
- `move_player_to_clicked_position(grid_position: Vector2i)` - Move the player to a clicked grid position
- `move_player_along_path(path: Array)` - Move the player along a calculated path
- `update_player_position(grid_position: Vector2i)` - Update the player's position based on a grid position
- `grid_to_world(grid_position: Vector2i) -> Vector3` - Convert a grid position to a world position

## Extending the Plugin

### Custom Item States

You can add custom item states to the EnhancedGridMap:

1. In the `EnhancedGridMap` dock, click the "Add Item State" button.
2. Set a name, ID, and randomization properties for the new state.
3. Use the new state's ID when setting cell types in your scripts.

### Custom Pathfinding Costs

Override the `get_cell_cost` method in a script extending EnhancedGridMap to implement custom pathfinding costs:

```gdscript
extends EnhancedGridMap

func get_cell_cost(x: int, z: int) -> float:
    var cell_item = get_cell_item(Vector3i(x, 0, z))
    match cell_item:
        0: return 1.0  # Normal cell
        1: return 2.0  # Slow terrain
        2: return 0.5  # Fast terrain
        _: return INF  # Non-walkable
```

### Custom Grid Generation

You can implement custom grid generation by overriding the `generate_grid` method:

```gdscript
extends EnhancedGridMap

func generate_grid():
    clear()
    for x in range(columns):
        for z in range(rows):
            var item_index = (x + z) % 2  # Checkerboard pattern
            set_cell_item(Vector3i(x, 0, z), item_index)
    update_grid_data()
    initialize_astar()
    update_astar_costs()
```

## Extending the Player Movement

You can extend the player movement functionality by overriding or adding methods to the `player.gd` script. For example:

### Custom Movement Rules

```gdscript
extends "res://addons/enhanced_gridmap/examples/player.gd"

func is_valid_move(from: Vector2i, to: Vector2i) -> bool:
    # Add custom logic for valid moves
    var distance = from.distance_to(to)
    return distance <= 1 and super.is_valid_move(from, to)
```

### Additional Interactions

```gdscript
extends "res://addons/enhanced_gridmap/examples/player.gd"

func _unhandled_input(event):
    super._unhandled_input(event)
    
    if event.is_action_pressed("interact"):
        interact_with_current_cell()

func interact_with_current_cell():
    var cell_item = enhanced_gridmap.get_cell_item(Vector3i(current_position.x, 0, current_position.y))
    # Add custom interaction logic based on cell_item
```

These examples demonstrate how you can build upon the provided player movement script to create more complex game mechanics that integrate seamlessly with the EnhancedGridMap plugin.

## Contributing

Contributions to the EnhancedGridMap plugin are welcome! Please submit pull requests or issues on the project's GitHub repository.

## License

This plugin is released under the MIT License. See the LICENSE file for details.
