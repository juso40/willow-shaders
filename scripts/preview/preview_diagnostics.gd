class_name PreviewDiagnostics
extends RefCounted
## Display materials only. Family-specific modes come from the material's actual base.

const GEOMETRY := preload("res://shaders/preview_geometry.gdshader")
const SURFACE := {0: "Lit", 1: "Unlit", 2: "Wireframe"}
const MESH := {10: "UV1", 11: "UV2", 12: "UV1 checker", 13: "UV2 checker",
	14: "Mesh normals (view space)", 15: "Tangents (view space)", 16: "Vertex color"}
const IMAGE := {20: "Texture RGB", 21: "Texture R", 22: "Texture G", 23: "Texture B", 24: "Texture alpha"}

var mode := 0
var texture_name := ""
var names: Array[String] = []
var images := {}
var source: ShaderMaterial
var instance: UnrealMaterialInterface
var profile: MaterialDebugProfile
var groups: Array[Dictionary] = []
var neutral := StandardMaterial3D.new()
var display := ShaderMaterial.new()
var family_display := ShaderMaterial.new()
var wire := StandardMaterial3D.new()

func _init() -> void:
	wire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire.albedo_color = Color(0.1, 1.0, 0.7)
	display.shader = GEOMETRY
	set_source(null, null)

func set_source(value: ShaderMaterial, mic: UnrealMaterialInterface) -> void:
	source = value
	instance = mic
	images = mic.resolved_values(&"TextureParameterValues") if mic else {}
	names = MaterialParameterCatalog.names_for(mic, &"TextureParameterValues")
	if not texture_name in names: texture_name = str(names[0]) if not names.is_empty() else ""
	var previous := profile
	profile = null
	var base := MaterialParameterCatalog.master_for(mic) as UnrealMaterial
	if base and base.debug_profile and base.debug_profile.shader and value and value.shader == base.shader:
		profile = base.debug_profile
	groups = [{"title": "Surface", "entries": SURFACE}, {"title": "Geometry", "entries": MESH}]
	if not names.is_empty(): groups.append({"title": "Parameter image on UV1", "entries": IMAGE})
	if profile:
		var entries := profile.menu_entries()
		if not entries.is_empty(): groups.append({"title": profile.section, "entries": entries})
	if not supports(mode) or (mode >= MaterialDebugProfile.FIRST_VIEW and previous != profile): mode = 0

func uses_texture_picker() -> bool:
	return IMAGE.has(mode)

func supports(id: int) -> bool:
	for group in groups:
		if group.entries.has(id): return true
	return false

func material_for(viewport: Viewport) -> Material:
	var family_view := profile != null and (mode >= MaterialDebugProfile.FIRST_VIEW or (mode == 1 and profile.provides_unlit))
	var has_shader := source != null and source.shader != null
	neutral.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if mode == 1 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED if mode == 1 and has_shader and not family_view else Viewport.DEBUG_DRAW_DISABLED
	if family_view:
		family_display.shader = profile.shader
		instance.apply_to_material(family_display)
		family_display.set_shader_parameter("diagnostic_view", mode)
		return family_display
	if mode <= 1: return source if has_shader else neutral
	if mode == 2: return wire
	display.set_shader_parameter("image", images.get(texture_name))
	display.set_shader_parameter("has_image", images.get(texture_name) != null)
	display.set_shader_parameter("diagnostic_view", mode)
	return display
