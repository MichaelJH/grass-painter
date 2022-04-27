tool
extends EditorSpatialGizmoPlugin

const NUM_CIRCLE_POINTS = 200

func get_name() -> String:
	return "GrassPainter"


func _init() -> void:
	create_material("brush", Color(1.0, 0.8, 0.0, 0.8))
	create_material("multimesh", Color(1.0, 0.0, 0.0, 0.8))

func has_gizmo(spatial: Spatial) -> bool:
	return spatial is GrassPainter


func redraw(gizmo: EditorSpatialGizmo) -> void:
	if gizmo == null:
		return
	
	gizmo.clear()
	
	var painter : GrassPainter = gizmo.get_spatial_node() as GrassPainter
	if not painter.show_gizmo:
		return
	
	var lines := _draw_painter_gizmo(painter)
	
	gizmo.add_lines(lines, get_material("brush", gizmo), true)


func _draw_painter_gizmo(painter : GrassPainter) -> PoolVector3Array:
	var lines : PoolVector3Array
	if painter.is_grass_baked():
		lines = _draw_multimeshes(painter)
	elif painter.paint_mode_active:
		lines = _draw_brush(painter)
	
	return lines


func _draw_brush(painter : GrassPainter) -> PoolVector3Array:
	var lines : PoolVector3Array
	if painter.brush_type == 1:
		lines = _draw_square_brush(painter)
	else:
		lines = _draw_circle_brush(painter)
	
	return lines


func _draw_square_brush(painter : GrassPainter) -> PoolVector3Array:
	var lines := PoolVector3Array()
	var c := Vector3.ZERO #painter.target_point
	var h : float = 0.5
	var extent : float = painter.brush_size * painter.BLADE_DISTANCE / 2.0
	
	lines.append(c + Vector3(-extent, h, -extent))
	lines.append(c + Vector3(-extent, h,  extent))
	
	lines.append(c + Vector3(-extent, h,  extent))
	lines.append(c + Vector3( extent, h,  extent))
	
	lines.append(c + Vector3( extent, h,  extent))
	lines.append(c + Vector3( extent, h, -extent))
	
	lines.append(c + Vector3( extent, h, -extent))
	lines.append(c + Vector3(-extent, h, -extent))
	
	return lines


func _draw_circle_brush(painter : GrassPainter) -> PoolVector3Array:
	var lines := PoolVector3Array()
	var c := Vector3.ZERO #painter.target_point
	var h : float = 0.5
	var r : float = float(painter.brush_size) * painter.BLADE_DISTANCE / 2.0
	var theta : float = 0.0
	var x : float = r * cos(theta)
	var z : float = r * sin(theta)
	
	var start_point := c + Vector3(x, h, z)
	var end_point : Vector3
	var increment : float = 2.0 * PI / float(NUM_CIRCLE_POINTS)
	
	for i in range(1, NUM_CIRCLE_POINTS + 1):
		theta = float(i) * increment
		x = r * cos(theta)
		z = r * sin(theta)
		end_point = c + Vector3(x, h, z)
		
		lines.append(start_point)
		lines.append(end_point)
		
		start_point = end_point
	
	return lines


func _draw_multimeshes(painter : GrassPainter) -> PoolVector3Array:
	var lines := PoolVector3Array()
	
	for i in painter.get_baked_mesh_parent().get_child_count():
		var mesh_inst : MultiMeshInstance = painter.get_baked_mesh_parent().get_child(i)
		lines.append_array(_draw_multimesh(mesh_inst.transform.origin, mesh_inst.multimesh))
	
	return lines


func _draw_multimesh(offset : Vector3, multimesh : MultiMesh) -> PoolVector3Array:
	var lines := PoolVector3Array()
	var aabb := multimesh.get_aabb()
	lines.append_array(draw_square(offset, aabb, offset.y + aabb.end.y))
	lines.append_array(draw_square(offset, aabb, offset.y + aabb.position.y))
	lines.append_array(draw_verticals(offset, aabb))
	return lines


func draw_square(center : Vector3, aabb : AABB, h : float) -> PoolVector3Array:
	var lines := PoolVector3Array()
	
	var cp := Vector3(center.x, h, center.z)
	lines.append(cp + Vector3(aabb.position.x, 0.0, aabb.position.z))
	lines.append(cp + Vector3(aabb.position.x, 0.0, aabb.end.z))
	
	lines.append(cp + Vector3(aabb.position.x, 0.0, aabb.end.z))
	lines.append(cp + Vector3(aabb.end.x, 0.0, aabb.end.z))
	
	lines.append(cp + Vector3(aabb.end.x, 0.0, aabb.end.z))
	lines.append(cp + Vector3(aabb.end.x, 0.0, aabb.position.z))
	
	lines.append(cp + Vector3(aabb.end.x, 0.0, aabb.position.z))
	lines.append(cp + Vector3(aabb.position.x, 0.0, aabb.position.z))
	
	return lines


func draw_verticals(center : Vector3, aabb : AABB) -> PoolVector3Array:
	var lines := PoolVector3Array()
	
	lines.append(center + Vector3(aabb.position.x, aabb.position.y, aabb.position.z))
	lines.append(center + Vector3(aabb.position.x, aabb.end.y, aabb.position.z))
	
	lines.append(center + Vector3(aabb.position.x, aabb.position.y, aabb.end.z))
	lines.append(center + Vector3(aabb.position.x, aabb.end.y, aabb.end.z))
	
	lines.append(center + Vector3(aabb.end.x, aabb.position.y, aabb.position.z))
	lines.append(center + Vector3(aabb.end.x, aabb.end.y, aabb.position.z))
	
	lines.append(center + Vector3(aabb.end.x, aabb.position.y, aabb.end.z))
	lines.append(center + Vector3(aabb.end.x, aabb.end.y, aabb.end.z))
	
	return lines
