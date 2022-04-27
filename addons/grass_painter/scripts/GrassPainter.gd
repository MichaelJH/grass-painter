tool
extends MeshInstance

class_name GrassPainter

# This signal is emitted for the plugin to receive any time this script makes changes
# that should be saved (to use UndoRedo to mark the scene dirty)
signal data_changed

const GrassFactory : GDScript = preload("res://addons/grass_painter/scripts/GrassFactory.gd")
const GrassUtils : GDScript = preload("res://addons/grass_painter/scripts/GrassPainterUtils.gd")
#To use with hterrain, uncomment this line and lines 400-402
#const HTerrain : GDScript = preload("res://addons/zylann.hterrain/hterrain.gd")
const PAINT_MATERIAL : Material = preload("res://addons/grass_painter/materials/grass_paint_mat.tres")
const SPRING_GRASS : Material = preload("res://addons/grass_painter/materials/spring_grass_mat.tres")

const PAINT_MESH_INST_NAME := "GrassPaintMesh"
const RAYCAST_NAME := "RayCast"
const BAKE_PARENT_NAME := "BakedMeshes"

const RAY_LENGTH = 500.0
const BRUSH_MASK = 1
const BLADE_DISTANCE = 0.25
const HALF_DISTANCE = 0.125

# Setup properties
var target_scene : NodePath
var target_hterrain : NodePath
var resource_filename : String
var baked_mesh_size : float
var resource_dirty := false

# Brush properties
var brush_type : int
var brush_size : int
var ground_angle_variance : float
var ground_height_variance : float

# Grass properties
var height_range : Vector2
var width_range : Vector2
var sway_yaw : Vector2
var sway_pitch : Vector2
var grass_material : Material

# Referenced or set by plugin
var paint_mode_active : bool = false
var show_gizmo : bool = false
var scene_root : Node

var grass_data_map : GrassMap
var _island_aabb : AABB
var _base_position : Vector3
var _extents : Vector3
var _clear_grass_pending : bool = false
var _noise : OpenSimplexNoise

var _target_normal : Vector3
var _target_point : Vector3

# Node references
var _paint_multimesh_inst : MultiMeshInstance
var _paint_multimesh : MultiMesh
var _raycaster : RayCast
var _baked_mesh_parent : Spatial

# ================================================================== #
#                       EDITOR PROPERTIES                            #
# ================================================================== #

func _init() -> void:
	baked_mesh_size = 40.0
	grass_material = SPRING_GRASS
	brush_type = 0
	brush_size = 40
	ground_angle_variance = 10.0
	ground_height_variance = 3.0
	height_range = Vector2(1.0, 1.1)
	width_range = Vector2(0.25, 0.5)
	sway_yaw = Vector2(0.0, 10.0)
	sway_pitch = Vector2(0.0, 10.0)


func _get(property: String):
	var segments := property.split("/")

	if segments.size() > 1:
		match(segments[1]):
			"target_scene":
				return target_scene
			"target_hterrain":
				return target_hterrain
			"resource_filename":
				return resource_filename
			"baked_mesh_size":
				return baked_mesh_size
			"brush_type":
				return brush_type
			"brush_size":
				return brush_size
			"ground_angle_variance":
				return ground_angle_variance
			"ground_height_variance":
				return ground_height_variance
			"height_range":
				return height_range
			"width_range":
				return width_range
			"sway_yaw":
				return sway_yaw
			"sway_pitch":
				return sway_pitch
			"material":
				return grass_material


func _set(property: String, value) -> bool:
	var segments := property.split("/")
	var exists := true
	
	if segments.size() > 1:
		match(segments[1]):
			"target_scene":
				_set_target_scene(value)
			"target_hterrain":
				_set_target_hterrain(value)
			"resource_filename":
				_set_resource_filename(value)
			"baked_mesh_size":
				_set_baked_mesh_size(value)
			"brush_type":
				brush_type = value
			"brush_size":
				brush_size = value
			"ground_angle_variance":
				ground_angle_variance = value
			"ground_height_variance":
				ground_height_variance = value
			"height_range":
				height_range = value
			"width_range":
				width_range = value
			"sway_yaw":
				sway_yaw = value
			"sway_pitch":
				sway_pitch = value
			"material":
				_set_grass_material(value)
			_:
				exists = false
	else:
		exists = false
	return exists


func _get_property_list() -> Array:
	var properties : Array
	
	_add_build_properties(properties)
	_add_brush_properties(properties)
	_add_grass_properties(properties)
	
	return properties


func _add_build_properties(properties : Array) -> void:
	var category : String = "setup"
	
	properties.append_array([{
		"name": category + "/target_scene",
		"type": TYPE_NODE_PATH
	}, {
		"name": category + "/target_hterrain",
		"type": TYPE_NODE_PATH
	}, {
		"name": category + "/resource_filename",
		"type": TYPE_STRING
	}, {
		"name": category + "/baked_mesh_size",
		"type": TYPE_REAL,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,100.0,or_greater"
	}])


func _add_brush_properties(properties : Array) -> void:
	var category : String = "brush"
	
	properties.append_array([{
		"name": category + "/brush_type",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Round,Square"
	}, {
		"name": category + "/brush_size",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,250,or_greater"
	}, {
		"name": category + "/ground_angle_variance",
		"type": TYPE_REAL,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0, 90.0"
	}, {
		"name": category + "/ground_height_variance",
		"type": TYPE_REAL,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,20.0,or_greater"
	}])


func _add_grass_properties(properties : Array) -> void:
	var category : String = "grass"
	
	properties.append_array([{
		"name": category + "/height_range",
		"type": TYPE_VECTOR2
	}, {
		"name": category + "/width_range",
		"type": TYPE_VECTOR2
	}, {
		"name": category + "/sway_yaw",
		"type": TYPE_VECTOR2
	}, {
		"name": category + "/sway_pitch",
		"type": TYPE_VECTOR2
	}, {
		"name": category + "/material",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Material"
	}])

# ================================================================== #
#                             SETTERS                                #
# ================================================================== #

func _ignore_set(_val) -> void:
	pass


func _set_target_scene(val : NodePath) -> void:
	target_scene = val
	target_hterrain = NodePath()
	property_list_changed_notify()
	update_configuration_warning()


func _set_target_hterrain(val : NodePath) -> void:
	target_hterrain = val
	target_scene = NodePath()
	property_list_changed_notify()
	update_configuration_warning()


func _set_resource_filename(val : String) -> void:
	resource_filename = val
	update_configuration_warning()


func _set_grass_material(val : Material) -> void:
	grass_material = val
	if is_grass_baked():
		_set_baked_grass_material()


func _set_baked_mesh_size(val : float) -> void:
	if is_inside_tree() and is_grass_baked() and val != baked_mesh_size:
		_begin_paint()
		baked_mesh_size = val
		_bake_grass()

		property_list_changed_notify()
		show_gizmo = true
		update_gizmo()
		emit_signal("data_changed")
	else:
		baked_mesh_size = val

# ================================================================== #
#                        EDITOR & VALIDATION                         #
# ================================================================== #

func _get_configuration_warning() -> String:
	if target_scene.is_empty() and target_hterrain.is_empty():
		return "Must provide an Island Scene target or an HTerrain target"
	if resource_filename == "":
		return "Must provide a resource filename"
	return ""


func _get_tool_buttons() -> Array:
	var out : Array
	if not paint_mode_active:
		out.append({text = "Paint Grass", call = "_try_paint_grass", tint = Color.lawngreen})
	if not is_grass_baked():
		out.append({text = "Bake Grass", call="_try_bake_grass", tint = Color.aqua})
	out.append({text = "Clear Grass", call="_inquire_clear", tint = Color.orange})
	if _clear_grass_pending:
		out.append({text = "Cancel Clear", call="_cancel_clear", tint = Color.tomato})
		out.append({text = "Confirm Clear", call="_confirm_clear", tint = Color.lime})
	return out


func _can_begin_paint() -> bool:
	return _basic_requirements_done()


func _can_begin_bake() -> bool:
	return _basic_requirements_done() and grass_data_map != null


func _can_clear_grass() -> bool:
	return _basic_requirements_done()


func _basic_requirements_done() -> bool:
	return is_inside_tree() and not (target_scene.is_empty() and target_hterrain.is_empty()) and resource_filename != ""


func get_baked_mesh_parent() -> Spatial:
	return _baked_mesh_parent


# ================================================================== #
#                          BUTTON HANDLERS                           #
# ================================================================== #

func _try_paint_grass() -> void:
	if _can_begin_paint():
		_begin_paint()
		
		paint_mode_active = true
		
		property_list_changed_notify()
		show_gizmo = false
		update_gizmo()
		emit_signal("data_changed")
	else:
		_warn_necessary_elements()


func _try_bake_grass() -> void:
	if _can_begin_bake():
		_bake_grass()
		
		paint_mode_active = false
		
		property_list_changed_notify()
		show_gizmo = true
		update_gizmo()
		emit_signal("data_changed")
	else:
		_warn_necessary_elements()


func _inquire_clear() -> void:
	_clear_grass_pending = not _clear_grass_pending
	property_list_changed_notify()


func _cancel_clear() -> void:
	_clear_grass_pending = false
	property_list_changed_notify()


func _confirm_clear() -> void:
	_clear_grass_pending = false
	if _can_clear_grass():
		_clear_grass()
		
#		grass_data_map.grass_is_baked = false
		if paint_mode_active:
			_try_paint_grass()
		
		property_list_changed_notify()
		show_gizmo = false
		update_gizmo()
		emit_signal("data_changed")
	else:
		_warn_necessary_elements()

# ================================================================== #
#                          INITIALIZATION                            #
# ================================================================== #


func _initialize_noise() -> void:
	if _noise == null:
		_noise = OpenSimplexNoise.new()
		_noise.octaves = 4
		_noise.period = 50.0
		_noise.persistence = 0.8
	
	if grass_data_map.noise_seed != 0:
		_noise.seed = grass_data_map.noise_seed
	else:
		var new_seed : int = randi()
		# For the one in billions case where randi produces 0
		while new_seed == 0:
			new_seed = randi()
		_noise.seed = new_seed
		grass_data_map.noise_seed = new_seed


func _initialize_map_data(reset : bool) -> void:
	_initialize_dimensions()
	if reset:
		grass_data_map = GrassMap.new()
		grass_data_map.initialize(_base_position, _extents, BLADE_DISTANCE)
	elif grass_data_map == null:
		if _data_exists():
			grass_data_map = load(filepath()) as GrassMap
		else:
			grass_data_map = GrassMap.new()
			grass_data_map.initialize(_base_position, _extents, BLADE_DISTANCE)


func _create_fresh_paint_multimesh() -> void:
	if _paint_multimesh == null:
		_paint_multimesh = MultiMesh.new()
	
	_clear_paint_multimesh()
	_paint_multimesh.mesh = GrassFactory.simple_grass()
	_paint_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_paint_multimesh.set_custom_data_format(MultiMesh.CUSTOM_DATA_FLOAT)
	_paint_multimesh.set_color_format(MultiMesh.COLOR_NONE)
	_paint_multimesh.instance_count = grass_data_map.map.size()
	grass_data_map.curr_mesh_index = 0



func _initialize_dimensions() -> void:
	if (target_scene.is_empty() and target_hterrain.is_empty()) or not is_inside_tree():
		return
	
	if not target_scene.is_empty():
		var island : Spatial = get_node(target_scene)
		_island_aabb = island.get_transformed_aabb()
	#else:
	#	var terrain : HTerrain = get_node(target_hterrain)
	#	_island_aabb = terrain.get_data().get_aabb()
	
	
	_base_position = _island_aabb.position.floor()
	
	_extents = _island_aabb.size + (_island_aabb.position - _base_position)
	_extents = _extents.ceil()


func _initialize_raycaster() -> void:
	_raycaster = get_node(_relative_node_path(RAYCAST_NAME))
	if _raycaster == null:
		push_error("Raycaster cannot be retrieved")
		return
	_raycaster.collision_mask = BRUSH_MASK
	_raycaster.enabled = false

# ================================================================== #
#                             UTILITY                                #
# ================================================================== #

func _warn_necessary_elements() -> void:
	push_warning("You must specify a scene and resource filename before you can paint, bake or clear grass")


func is_grass_baked() -> bool:
	if not _update_references():
		return false
	return _baked_mesh_parent.get_child_count() > 0


func filepath() -> String:
	return GrassUtils.directory_path + resource_filename + ".tres"


func _data_exists() -> bool:
	var dir = Directory.new()
	return dir.file_exists(filepath())


func _relative_node_path(node_name : String) -> NodePath:
	return NodePath(node_name)


func _update_references() -> bool:
	if get_child_count() < 3:
		if not _create_utility_nodes():
			return false
	
	_paint_multimesh_inst = get_node(_relative_node_path(PAINT_MESH_INST_NAME))
	if _paint_multimesh_inst != null:
		_paint_multimesh = _paint_multimesh_inst.multimesh
	_raycaster = get_node(_relative_node_path(RAYCAST_NAME))
	_baked_mesh_parent = get_node(_relative_node_path(BAKE_PARENT_NAME))
	return true


func _create_utility_nodes() -> bool:
	if scene_root == null:
		return false
	
	_create_one_utility_node(MultiMeshInstance.new(), PAINT_MESH_INST_NAME)
	_create_one_utility_node(RayCast.new(), RAYCAST_NAME)
	_create_one_utility_node(Spatial.new(), BAKE_PARENT_NAME)
	
	emit_signal("data_changed")
	return true


func _create_one_utility_node(node : Node, node_name : String):
	add_child(node)
	node.name = node_name
	node.set_owner(scene_root)
	
	if node is MultiMeshInstance:
		node.multimesh = MultiMesh.new()
		node.cast_shadow = false


func _clear_paint_multimesh() -> void:
	_paint_multimesh.instance_count = 0


func _clear_bake_meshes() -> void:
	for i in _baked_mesh_parent.get_child_count():
		_baked_mesh_parent.get_child(i).queue_free()
	grass_data_map.baked_mesh_init_dims.clear()


func _rebuild_overflow_paint_mesh() -> void:
	var tx_array : Array
	var data_array : Array
	# Grab transform and custom data for every visible blade of grass
	for i in (grass_data_map.map.size()):
		var m_index = grass_data_map.get_mesh_index(i)
		if m_index != -1:
			tx_array.append(_paint_multimesh.get_instance_transform(m_index))
			data_array.append(_paint_multimesh.get_instance_custom_data(m_index))
	
	# Rebuild multimesh with all of the visible grass front-loaded
	_create_fresh_paint_multimesh()
	for i in (grass_data_map.map.size()):
		if grass_data_map.map[i] != -1:
			_create_grass_blade_tx(tx_array[grass_data_map.curr_mesh_index], data_array[grass_data_map.curr_mesh_index])
			grass_data_map.grass_placed(i, grass_data_map.curr_mesh_index)
			grass_data_map.curr_mesh_index += 1


func set_active(active : bool) -> void:
	show_gizmo = active
	if active == false:
		transform.origin = Vector3.ZERO
		if _paint_multimesh_inst != null:
			_paint_multimesh_inst.transform.origin = Vector3.ZERO
	if _raycaster != null:
		_raycaster.enabled = active


func _get_bake_dim_cell_count() -> int:
	return int(baked_mesh_size / BLADE_DISTANCE)


func _set_baked_grass_material() -> void:
	for i in _baked_mesh_parent.get_child_count():
		_baked_mesh_parent.get_child(i).material_override = grass_material


# ================================================================== #
#                     BEGIN CORE ACTIONS                             #
# ================================================================== #

func _begin_paint() -> void:
	_update_references()
	_initialize_painting()
	_clear_bake_meshes()
	_initialize_noise()


func _bake_grass() -> void:
	set_active(false)
	_update_references()
	_initialize_map_data(false)
	_bake_efficient_multimeshes()
	_clear_paint_multimesh()


func _clear_grass() -> void:
	_update_references()
	if grass_data_map == null:
		_initialize_map_data(false)
	_clear_bake_meshes()
	_initialize_map_data(true)
	_rebuild_overflow_paint_mesh()
	_initialize_noise()

# ================================================================== #
#                           PREP PAINT                               #
# ================================================================== #

func _initialize_painting() -> void:
	_initialize_map_data(false)
	if _paint_multimesh_inst.material_override == null:
		_paint_multimesh_inst.material_override = PAINT_MATERIAL
	if is_grass_baked():
		_unbake_grass()

# ================================================================== #
#                     PAINT MESH -> BAKE MESH                        #
# ================================================================== #

func _bake_efficient_multimeshes() -> void:
	var mesh_size_by_cells := _get_bake_dim_cell_count()
	var num_meshes : Vector2 = grass_data_map.get_num_meshes(mesh_size_by_cells)
	
	var w = int(num_meshes.x)
	var l = int(num_meshes.y)
	
	_clear_bake_meshes()
	
	for z in l:
		for x in w:
			_create_and_populate_multimesh(z, x, mesh_size_by_cells)


func _get_bake_mesh_origin_from_base_coords(base_x : float, base_z : float, mesh_size_by_cells : int) -> Vector3:
	var origin = grass_data_map.get_pos_from_dims(base_x, base_z)
	var half_mesh_dist := float(mesh_size_by_cells) * BLADE_DISTANCE / 2.0
	origin.x += half_mesh_dist
	origin.z += half_mesh_dist
	return origin


func _get_base_coords_from_bake_mesh_origin(origin : Vector3, mesh_size_by_cells : int) -> Vector2:
	var half_mesh_dist := float(mesh_size_by_cells) * BLADE_DISTANCE / 2.0
	origin.x -= half_mesh_dist
	origin.z -= half_mesh_dist
	
	return Vector2.ZERO


func _create_and_populate_multimesh(z : int, x : int, mesh_size_by_cells : int) -> void:
	var init_x = x * mesh_size_by_cells
	var init_z = z * mesh_size_by_cells
	
	var origin = grass_data_map.get_pos_from_dims(init_x, init_z)
	var half_dist : float = float(mesh_size_by_cells) * BLADE_DISTANCE / 2.0
	origin.x += half_dist
	origin.z += half_dist
	
	var mesh_instance = _create_multimesh_instance(origin, mesh_size_by_cells * mesh_size_by_cells)
	_baked_mesh_parent.add_child(mesh_instance)
	if scene_root != null:
		mesh_instance.set_owner(scene_root)
	var mmesh = mesh_instance.multimesh
	
	var bake_index := 0
	
	for z in mesh_size_by_cells:
		for x in mesh_size_by_cells:
			var curr_x = init_x + x
			var curr_z = init_z + z
			
			var map_index = grass_data_map.get_index_from_dims(curr_x, curr_z)
			if map_index == -1: continue
			var paint_index = grass_data_map.get_mesh_index(map_index)
			if paint_index == -1: continue
			
			_transfer_blade_between_meshes(_paint_multimesh_inst, mesh_instance, paint_index, bake_index)
			grass_data_map.grass_placed(map_index, bake_index)
			
			bake_index += 1

	
	if bake_index == 0:
		mesh_instance.free()
	else:
		grass_data_map.baked_mesh_init_dims.append(Vector2(init_x, init_z))


func _create_multimesh_instance(origin : Vector3, instance_count : int) -> MultiMeshInstance:
	var mesh_instance = MultiMeshInstance.new()
	var mmesh = MultiMesh.new()
	mesh_instance.multimesh = mmesh
	mesh_instance.material_override = grass_material
	mesh_instance.cast_shadow = false
	mesh_instance.transform.origin = origin
	
	mmesh.mesh = GrassFactory.simple_grass()
	mmesh.transform_format = MultiMesh.TRANSFORM_3D
	mmesh.set_custom_data_format(MultiMesh.CUSTOM_DATA_FLOAT)
	mmesh.set_color_format(MultiMesh.COLOR_NONE)
	mmesh.instance_count = instance_count
	
	return mesh_instance


func _transfer_blade_between_meshes(m_from : MultiMeshInstance, m_to : MultiMeshInstance, i_from : int, i_to : int) -> void:
	var from_origin = m_from.transform.origin
	var to_origin = m_to.transform.origin
	
	var tx : Transform = m_from.multimesh.get_instance_transform(i_from)
	tx.origin += from_origin
	tx.origin -= to_origin
	
	var data : Color = m_from.multimesh.get_instance_custom_data(i_from)
	
	m_to.multimesh.set_instance_transform(i_to, tx)
	m_to.multimesh.set_instance_custom_data(i_to, data)

# ================================================================== #
#                     PAINT MESH -> BAKE MESH                        #
# ================================================================== #

func _unbake_grass() -> void:
	_create_fresh_paint_multimesh()
	_do_unbake()


func _do_unbake() -> void:
	var mesh_size_by_cells := _get_bake_dim_cell_count()
	
	for i in _baked_mesh_parent.get_child_count():
		var bake_mesh = _baked_mesh_parent.get_child(i)
		var init_dims = grass_data_map.baked_mesh_init_dims[i]
		_unbake_one_mesh(bake_mesh, init_dims, mesh_size_by_cells)


func _unbake_one_mesh(bake_mesh : MultiMeshInstance, init_dims : Vector2, mesh_size_by_cells : int) -> void:
	for z in mesh_size_by_cells:
		for x in mesh_size_by_cells:
			var curr_x = int(init_dims.x) + x
			var curr_z = int(init_dims.y) + z
			
			var map_index = grass_data_map.get_index_from_dims(curr_x, curr_z)
			if map_index == -1: continue
			var bake_index = grass_data_map.get_mesh_index(map_index)
			if bake_index == -1: continue
			
			_transfer_blade_between_meshes(bake_mesh, _paint_multimesh_inst, bake_index, grass_data_map.curr_mesh_index)
			grass_data_map.grass_placed(map_index, grass_data_map.curr_mesh_index)
			
			grass_data_map.curr_mesh_index += 1


# ================================================================== #
#                               BRUSH                                #
# ================================================================== #


func paint_grass(mouse_pos : Vector2, camera : Camera) -> void:
	if not paint_mode_active:
		return
	var made_change := false
	update_brush_position(mouse_pos, camera)
	var h = max((ground_height_variance + 0.1) * 2.0, 3.0)
	var cast
	if _raycaster == null:
		_initialize_raycaster()
	_raycaster.cast_to = Vector3(0.0, -(h + ground_height_variance), 0.0)
	var base_x = -(float(brush_size) * BLADE_DISTANCE / 2.0) + HALF_DISTANCE
	var base_z = -(float(brush_size) * BLADE_DISTANCE / 2.0) + HALF_DISTANCE
	for i in (brush_size):
		for j in (brush_size):
			var offset = Vector3(
				base_x + (BLADE_DISTANCE * j),
				h,
				base_z + (BLADE_DISTANCE * i)
			)
			# For round brush
			if brush_type == 0 and Vector2(offset.x, offset.z).length() > brush_size * BLADE_DISTANCE / 2.0:
				continue
			
			var raycast_pos = _target_point + offset #map_data.get_index_pos_center(target_point + offset)
			var map_index : int = grass_data_map.get_map_index(raycast_pos)
			if map_index == -1:
				continue
			if Input.is_key_pressed(KEY_CONTROL):
				var mesh_index : int = grass_data_map.get_mesh_index(map_index)
				if mesh_index == -1:
					continue
				
				raycast_pos = _paint_multimesh.get_instance_transform(mesh_index).origin
				raycast_pos.y += h
				_raycaster.global_transform.origin = raycast_pos
				_raycaster.force_raycast_update()
				if _raycast_valid():
					grass_data_map.clear_map_spot(map_index)
					_remove_grass_blade(mesh_index)
					made_change = true
			else:
				raycast_pos = raycast_pos + Vector3(rand_range(-HALF_DISTANCE, HALF_DISTANCE), 0.0, rand_range(-HALF_DISTANCE, HALF_DISTANCE))
				_raycaster.global_transform.origin = raycast_pos
				_raycaster.force_raycast_update()
				if _raycast_valid() and grass_data_map.should_place_blade_of_grass(map_index):
					_create_grass_blade(_raycaster.get_collision_point())
					grass_data_map.grass_placed(map_index, grass_data_map.curr_mesh_index)
					grass_data_map.curr_mesh_index += 1
					made_change = true
	if made_change:
		emit_signal("data_changed")


func _raycast_valid() -> bool:
	return _raycaster.is_colliding() and _valid_height(_raycaster.get_collision_point()) and _valid_normal(_raycaster.get_collision_normal())


func _valid_normal(to_check : Vector3) -> bool:
	return rad2deg(_target_normal.angle_to(to_check)) <= ground_angle_variance


func _valid_height(pos : Vector3) -> bool:
	return abs(_target_point.y - pos.y) <= ground_height_variance


func _create_grass_blade(pos : Vector3) -> void:
	if grass_data_map.curr_mesh_index == _paint_multimesh.instance_count:
		_rebuild_overflow_paint_mesh()
	
	var basis = Basis(Vector3.UP, deg2rad(rand_range(0, 359)))
	_paint_multimesh.set_instance_transform(grass_data_map.curr_mesh_index, Transform(basis, pos))
	
	var h : float = rand_range(height_range.x, height_range.y)
	var mult := clamp(_noise.get_noise_2d(pos.x, pos.z), 0.0, 1.0) + 1.0
	mult = clamp(mult * mult, 1.0, 3.0)
	h *= mult
	_paint_multimesh.set_instance_custom_data(grass_data_map.curr_mesh_index, Color(
		rand_range(width_range.x, width_range.y),
		h,
		deg2rad(rand_range(sway_pitch.x, sway_pitch.y)),
		deg2rad(rand_range(sway_yaw.x, sway_yaw.y))
	))


func _create_grass_blade_tx(tx : Transform, data : Color) -> void:
	if grass_data_map.curr_mesh_index == _paint_multimesh.instance_count:
		push_error("Grass paint multimesh is out of instances")
	
	_paint_multimesh.set_instance_transform(grass_data_map.curr_mesh_index, tx)
	_paint_multimesh.set_instance_custom_data(grass_data_map.curr_mesh_index, data)


func _remove_grass_blade(mesh_index : int) -> void:
	_paint_multimesh.set_instance_transform(mesh_index, Transform.IDENTITY.scaled(Vector3.ZERO))


func update_brush_position(mouse_pos : Vector2, camera : Camera) -> void:
	if not paint_mode_active:
		return
	
	var selection := _get_mouse_raycast_target(mouse_pos, camera)
	
	if selection.has("position"):
		set_active(true)
		self.transform.origin = selection.position
		_paint_multimesh_inst.transform.origin = Vector3(-translation.x, -translation.y, -translation.z)
		_target_normal = selection.normal
		_target_point = selection.position
		update_gizmo()
	else:
		set_active(false)


func _get_mouse_raycast_target(mouse_pos : Vector2, camera : Camera) -> Dictionary:
	var viewport := camera.get_viewport()
	var viewport_container = viewport.get_parent()
	var screen_pos = mouse_pos * viewport.size / viewport_container.rect_size
	var ray_from := camera.project_ray_origin(screen_pos)
	var ray_to := ray_from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
	
	var space_state : PhysicsDirectSpaceState = get_world().direct_space_state
	
	return space_state.intersect_ray(ray_from, ray_to, [], BRUSH_MASK)
