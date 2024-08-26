@tool
extends EditorPlugin

var dock

func _enter_tree():
	dock = preload("res://addons/enhanced_gridmap/enhanced_gridmap_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	add_custom_type("EnhancedGridMap", "GridMap", preload("res://addons/enhanced_gridmap/enhanced_gridmap.gd"), preload("res://addons/enhanced_gridmap/icon.png"))

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	remove_custom_type("EnhancedGridMap")

func _handles(object):
	return object is EnhancedGridMap

func _make_visible(visible):
	if dock:
		dock.visible = visible

func _get_plugin_name():
	return "EnhancedGridMap"

func _edit(object):
	if dock and object is EnhancedGridMap:
		dock.set_enhanced_gridmap(object)
