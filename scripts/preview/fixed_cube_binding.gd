class_name FixedCubeBinding
extends RefCounted
## Rebuild a preview cubemap only if one of its six exact face images changes.
## GPU layer order is +X, -X, +Y, -Y, +Z, -Z.

var _faces: Array[Texture2D] = []
var _cube: Cubemap

func resolve(paths: PackedStringArray, images: Dictionary) -> Cubemap:
	var faces: Array[Texture2D] = []
	for path in paths: faces.append(images.get(path))
	if faces == _faces: return _cube
	_faces = faces
	_cube = null
	if faces.size() != 6 or null in faces: return null
	var layers: Array[Image] = []
	for face in faces:
		var img := face.get_image()
		if not img or img.is_empty() or img.get_width() != img.get_height(): return null
		if not layers.is_empty() and layers[0].get_size() != img.get_size(): return null
		if img.is_compressed() and img.decompress() != OK: return null
		img.convert(Image.FORMAT_RGBA8)
		if not img.has_mipmaps(): img.generate_mipmaps()
		layers.append(img)
	var assembled := Cubemap.new()
	if assembled.create_from_images(layers) == OK: _cube = assembled
	return _cube
