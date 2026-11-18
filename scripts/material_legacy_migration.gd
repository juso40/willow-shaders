class_name MaterialLegacyMigration
extends RefCounted
## Read compatibility only. No obsolete preview controls are exposed or re-saved.

static func migrate_statics(target: UnrealMaterialInterface, values: Dictionary) -> void:
	if values.has("bl_WeapClassSelect"):
		var mask := Vector4.ZERO
		mask[clampi(int(values.bl_WeapClassSelect), 0, 2)] = 1.0
		target.static_component_masks["p_WeapClassSelect"] = mask
	var aliases := {"bl_PatternTextureChannel": "p_PatternChannel", "bl_DecalTextureChannel": "p_DecalChannel"}
	for old: String in aliases:
		if values.get(old) is Vector4: target.set_static_component_mask(aliases[old], values[old])
	if values.has("sw_FlipDecalOnRightSide"): target.static_switches["sw_FlipDecalOnRightSide"] = bool(values.sw_FlipDecalOnRightSide)
