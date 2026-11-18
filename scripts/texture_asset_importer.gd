class_name TextureAssetImporter
extends RefCounted
## Copies images into binary Godot texture resources. No editor reimport needed.
## Imported assets survive restarts and remain portable with the project.

static func import_image(path: String, directory := "user://textures") -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "Image file does not exist: " + path}
	var image := Image.new()
	var error := image.load(path)
	if error != OK: return {"error": "Cannot decode image: " + error_string(error)}
	if image.is_empty(): return {"error": "Image is empty."}
	image.generate_mipmaps()
	var texture: Texture2D = ImageTexture.create_from_image(image)
	texture.resource_name = path.get_file()
	texture.set_meta("imported_filename", path.get_file())
	var digest := FileAccess.get_sha256(path).left(16)
	var destination := directory.path_join(path.get_file().get_basename().validate_filename() + "_" + digest + ".res")
	error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return {"error": "Cannot create import directory: " + error_string(error)}
	# Content-addressed files are immutable: reimporting a changed image cannot
	# silently change other saved materials that reference a previous import.
	if ResourceLoader.exists(destination):
		texture = load(destination) as Texture2D
	else:
		error = ResourceSaver.save(texture, destination)
		if error != OK: return {"error": "Cannot save imported texture: " + error_string(error)}
		texture.take_over_path(destination)
	return {"texture": texture, "path": destination, "error": ""}
