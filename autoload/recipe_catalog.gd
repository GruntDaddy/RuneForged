extends Node

## Loads all `RecipeData` `.tres` under `res://data/recipes/` (recursive).

var _recipes: Dictionary = {}  ## id -> RecipeData


func _ready() -> void:
	_index_recipes_under("res://data/recipes")


func _index_recipes_under(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		push_warning("RecipeCatalog: cannot open %s" % dir_path)
		return
	d.list_dir_begin()
	var entry_name: String = d.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			var p: String = dir_path.path_join(entry_name)
			if d.current_is_dir():
				_index_recipes_under(p)
			elif entry_name.ends_with(".tres"):
				var res: Resource = ResourceLoader.load(p)
				if res is RecipeData:
					var r: RecipeData = res as RecipeData
					if r.id.is_empty():
						push_warning("RecipeCatalog: empty id in %s" % p)
					else:
						if _recipes.has(r.id):
							push_warning("RecipeCatalog: duplicate id '%s' (%s)" % [r.id, p])
						_recipes[r.id] = r
		entry_name = d.get_next()


func get_recipe(id: String) -> RecipeData:
	var v: Variant = _recipes.get(id, null)
	return v as RecipeData


func has_id(id: String) -> bool:
	return _recipes.has(id)


func get_all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _recipes.keys():
		out.append(str(k))
	return out


func get_all_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for k in _recipes.keys():
		var r: RecipeData = _recipes[k] as RecipeData
		if r != null:
			out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return out
