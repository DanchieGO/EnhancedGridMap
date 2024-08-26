# Enhanced GridMap Plugin for Godot

This plugin extends Godot's GridMap functionality, providing an intuitive interface for creating, editing, and pathfinding on grid-based maps.

## Features

- Dynamic grid generation and manipulation
- A* pathfinding visualization
- Customizable cell states (normal, hover, start, end, non-walkable)
- Random grid generation
- Fill grid with specific items
- UI for easy grid manipulation

## Installation

1. Clone this repository or download the ZIP file.
2. Copy the `addons/enhanced_gridmap` folder into your Godot project's `addons` folder.
3. Enable the plugin in your Godot project:
   - Go to "Project" -> "Project Settings" -> "Plugins"
   - Find "Enhanced GridMap" in the list and check the "Enable" box

## Setup

1. Add a new EnhancedGridMap node to your scene.
2. In the Inspector, assign a MeshLibrary to the EnhancedGridMap node.
   - Ensure your MeshLibrary has at least 5 items for normal, hover, start, end, and non-walkable states.
3. Adjust the columns and rows properties to set the grid size.
4. Set the auto_generate property to true if you want the grid to generate automatically.

## Usage

### Basic Grid Manipulation

- Use the Columns and Rows spinboxes to adjust the grid size.
- Click "Generate" to create the grid based on current settings.
- Click "Clear" to remove all items from the grid.
- Use "Randomize" to fill the grid with random normal and non-walkable cells.
- Select an item from the "Fill Options" dropdown and click "Fill" to set all cells to that item.

### Cell Editing

- In the grid view, click on any cell to open a dropdown menu.
- Select the desired item from the dropdown to change the cell's content.

### A* Pathfinding

1. Set the start position using the "Start X" and "Start Z" spinboxes.
2. Set the end position using the "End X" and "End Z" spinboxes.
3. Click "Find Path" to calculate and visualize the path.
4. The path result will be displayed below the button.

### Customizing Item States

Use the spinboxes in the "Item States" section to set which item index corresponds to each state:

- Normal Item
- Hover Item
- Start Item
- End Item
- Non-walkable Item

Ensure these indices match the order of items in your MeshLibrary.

## Notes

- The plugin automatically updates the A* pathfinding data when you modify the grid.
- Non-walkable cells are considered obstacles in pathfinding.
- The visualized path uses the "Hover Item" to show intermediate steps.

## API

The EnhancedGridMap class provides several reusable functions for grid manipulation and pathfinding. Here's a list of the key functions and their usage:

### Grid Manipulation

#### `generate_grid()`
Generates a new grid based on the current columns and rows settings.  
```gdscript
enhanced_gridmap.generate_grid()
```

#### `clear_grid()`
Clears all items from the grid.  
```gdscript
enhanced_gridmap.clear_grid()
```

#### `randomize_grid()`
Fills the grid with random normal and non-walkable cells.  
```gdscript
enhanced_gridmap.randomize_grid()
```

#### `fill_grid(item_index: int)`
Fills the entire grid with the specified item.  
```gdscript
enhanced_gridmap.fill_grid(item_index)
```

#### `set_cell_from_data(x: int, z: int, item_index: int)`
Sets a specific cell to the given item index.  
```gdscript
enhanced_gridmap.set_cell_from_data(x, z, item_index)
```

### Pathfinding

#### `initialize_astar()`
Initializes the A* pathfinding grid. Called automatically when generating or modifying the grid.  
```gdscript
enhanced_gridmap.initialize_astar()
```

#### `find_path(start: Vector2, end: Vector2) -> Array`
Finds and returns a path between two points on the grid.  
```gdscript
var path = enhanced_gridmap.find_path(Vector2(start_x, start_z), Vector2(end_x, end_z))
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.