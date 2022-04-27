extends HBoxContainer

var button : Button
var object : Object
var info : Dictionary

func _init(obj : Object, d) -> void:
	object = obj
	button = Button.new()
	
	if d is String:
		info = {"call": d}
	else:
		info = d as Dictionary
	
	alignment = BoxContainer.ALIGN_CENTER
	size_flags_horizontal = SIZE_EXPAND_FILL
	
	add_child(button)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.text = get_label()
	button.modulate = info.get("tint", Color.white)
	button.disabled = info.get("disabled", false)
	button.connect("pressed", self, "_on_button_pressed")
	
	button.hint_tooltip = "%s(%s)" % [info.call, get_args_string()]
	
	if "hint" in info:
		button.hint_tooltip += "\n%s" % [info.hint]
	
	button.flat = info.get("flat", false)
	button.align = info.get("align", Button.ALIGN_CENTER)
	
	if "icon" in info:
		button.expand_icon = false
		button.set_button_icon(load(info.icon))


func get_label() -> String:
	if "text" in info:
		return info.text
	
	if "args" in info:
		return "%s (%s)" % [info.call.capitalize(), get_args_string()]
	
	return info.call.capitalize()


func get_args_string() -> String:
	if not "args" in info:
		return ""
	
	var args = PoolStringArray()
	for a in info.args:
		if a is String:
			args.append('"%s"' % [a])
		else:
			args.append(str(a))
	
	return args.join(", ")


func _on_button_pressed() -> void:
	if "args" in info:
		var _0 = object.callv(info.call, info.args)
	else:
		var _0 = object.call(info.call)
