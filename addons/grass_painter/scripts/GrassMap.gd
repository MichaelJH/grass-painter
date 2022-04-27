tool
extends Resource

class_name GrassMap

export(int) var _base_x : int
export(int) var _base_z : int
export(int) var _ext_x : int
export(int) var _ext_z : int
export(int) var _dist : float

export(PoolIntArray) var map : PoolIntArray
export(Array) var baked_mesh_init_dims : Array # Array of Vector2
export(int) var curr_mesh_index : int
export(int) var noise_seed : int

func initialize(base : Vector3, extents : Vector3, dist : float) -> void:
	_base_x = int(base.x)
	_base_z = int(base.z)
	_ext_x = int(extents.x / dist)
	_ext_z = int(extents.z / dist)
	_dist = dist
	
	var size : int = int(_ext_x * _ext_z)
	map.resize(size)
	
	for i in (size):
		map[i] = -1
	
	curr_mesh_index = 0
	noise_seed = 0


func get_map_index(pos : Vector3) -> int:
	return get_index_from_pos(pos)


func should_place_blade_of_grass(index : int) -> bool:
	return map[index] == -1


func grass_placed(index : int, mesh_index : int) -> void:
	map[index] = mesh_index


func get_mesh_index(index : int) -> int:
	return map[index]


func clear_map_spot(index : int) -> void:
	map[index] = -1


func get_pos_from_dims(x : int, z : int) -> Vector3:
	var xf : float = float(_base_x) + (float(x) * _dist) + (_dist / 2.0)
	var zf : float = float(_base_z) + (float(z) * _dist) + (_dist / 2.0)
	
	return Vector3(xf, 0.0, zf)


func get_index_pos_center(pos : Vector3) -> Vector3:
	var xd := int((pos.x - _base_x) / _dist)
	var zd := int((pos.z - _base_z) / _dist)
	
	var x := _base_x + (float(xd) * _dist)
	var z := _base_z + (float(zd) * _dist)
	
	return Vector3(x, pos.y, z)


func get_index_from_pos(pos : Vector3) -> int:
	var xd := int((pos.x - _base_x) / _dist)
	var zd := int((pos.z - _base_z) / _dist)
	
	return get_index_from_dims(xd, zd)


func get_index_from_dims(x : int, z : int) -> int:
	if x < 0 or z < 0 or x >= _ext_x or z >= _ext_z:
		return -1
	
	return z * _ext_x + x


func get_num_meshes(cell_dimensions : int) -> Vector2:
	var dims : Vector2
	dims.x = ceil(float(_ext_x) / float(cell_dimensions))
	dims.y = ceil(float(_ext_z) / float(cell_dimensions))
	return dims
