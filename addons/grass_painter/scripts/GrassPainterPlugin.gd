tool
extends EditorPlugin

const GrassPainterGizmoPlugin : GDScript = preload("res://addons/grass_painter/scripts/GrassPainterGizmoPlugin.gd")
const GrassPainterInspectorPlugin : GDScript = preload("res://addons/grass_painter/scripts/GrassPainterInspectorPlugin.gd")
var _gizmo_plugin : EditorSpatialGizmoPlugin = GrassPainterGizmoPlugin.new()
var _inspector_plugin : EditorInspectorPlugin = GrassPainterInspectorPlugin.new()

var _undo_redo : UndoRedo

var _is_being_edited : bool
var _is_pressed : bool
var _grass_painter : GrassPainter
var _current_scene_root : Node
var _all_painters : Array

func _enter_tree() -> void:
	add_spatial_gizmo_plugin(_gizmo_plugin)
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	remove_spatial_gizmo_plugin(_gizmo_plugin)
	remove_inspector_plugin(_inspector_plugin)


func handles(object) -> bool:
	return object is GrassPainter


func edit(object) -> void:
	_grass_painter = object as GrassPainter
	if _grass_painter != null:
		_is_being_edited = true
		_grass_painter.set_active(true)
		_current_scene_root = get_editor_interface().get_edited_scene_root()
		_grass_painter.scene_root = _current_scene_root
		if not _grass_painter.is_connected("data_changed", self, "_on_painter_data_changed"):
			_grass_painter.connect("data_changed", self, "_on_painter_data_changed")
	else:
		push_warning("Grass painter plugin attempting to handle a non-grass-painter object...")


func _on_painter_data_changed() -> void:
	if _undo_redo == null:
		_undo_redo = get_undo_redo()
	_undo_redo.create_action("GrassChanged")
	_undo_redo.commit_action()
	_grass_painter.resource_dirty = true
	if not _all_painters.has(_grass_painter):
		_all_painters.append(_grass_painter)


func make_visible(visible : bool) -> void:
	if not visible:
		_is_being_edited = false
		if is_instance_valid(_grass_painter):
			_grass_painter.set_active(false)


func forward_spatial_gui_input(camera: Camera, event: InputEvent) -> bool:
	if not _is_being_edited or _grass_painter == null or not _grass_painter.paint_mode_active:
		return false
	
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		_is_pressed = event.pressed
		if _is_pressed:
			_grass_painter.paint_grass(event.position, camera)
		return true
	
	if event is InputEventMouseMotion:
		if _is_pressed:
			_grass_painter.paint_grass(event.position, camera)
		else:
			_grass_painter.update_brush_position(event.position, camera)
	
	return false


func save_external_data() -> void:
	var painters_to_remove : Array
	for p in _all_painters:
		var painter : GrassPainter = p as GrassPainter
		if not is_instance_valid(painter):
			continue
		var painter_root := painter.scene_root
		if not painter.is_inside_tree():
			continue
		if get_editor_interface().get_edited_scene_root() != painter_root:
			continue
		if not painter.resource_dirty:
			continue
		var resource_filename := painter.resource_filename
		if resource_filename == "":
			continue
		
		painters_to_remove.append(painter)
		painter.resource_dirty = false
		ResourceSaver.save(painter.filepath(), painter.grass_data_map, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	
	for p in painters_to_remove:
		_all_painters.erase(p)
	
