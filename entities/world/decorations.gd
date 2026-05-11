extends Node2D

func _ready() -> void:
	_set_z_indices(self)

func _set_z_indices(node: Node) -> void:
	for child in node.get_children():
		if child is Node2D:
			child.z_index = int((child as Node2D).global_position.y)
		_set_z_indices(child)
