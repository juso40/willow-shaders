class_name MaterialLibrary
extends RefCounted
## Applies a material to mesh instances without modifying shared mesh resources.

static func apply_to_tree(node: Node, material: Material) -> int:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: meshes.push_front(node)
	var count := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh:
			mesh.material_override = material
			count += 1
	return count
