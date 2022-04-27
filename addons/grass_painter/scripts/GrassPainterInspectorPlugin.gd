extends EditorInspectorPlugin

const InspectorButton = preload("res://addons/grass_painter/scripts/GrassPainterButton.gd")

func can_handle(object : Object) -> bool:
	return object is GrassPainter and object.has_method("_get_tool_buttons")


func parse_begin(object: Object) -> void:
	var methods : Array
	if object is Resource:
		methods = object.get_script()._get_tool_buttons()
	else:
		methods = object._get_tool_buttons()
	
	if methods:
		for method in methods:
			add_custom_control(InspectorButton.new(object, method))
