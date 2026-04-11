extends Node

## Uses InventoryService + RecipeCatalog. Does not consume `required_tool_ids`.

func can_craft(recipe: RecipeData, station: RecipeData.CraftStation) -> bool:
	if recipe == null:
		return false
	if recipe.station != RecipeData.CraftStation.NONE and recipe.station != station:
		return false
	for ing in recipe.inputs:
		if ing == null:
			continue
		if InventoryService.get_item_count(ing.item_id) < ing.count:
			return false
	for req_id in recipe.required_tool_ids:
		if req_id.is_empty():
			continue
		if not InventoryService.has_item(req_id):
			return false
	return true


func craft(recipe: RecipeData, station: RecipeData.CraftStation) -> bool:
	if not can_craft(recipe, station):
		return false
	var removed: Array[Dictionary] = []
	for ing in recipe.inputs:
		if ing == null:
			continue
		InventoryService.remove_item(ing.item_id, ing.count)
		removed.append({"id": ing.item_id, "count": ing.count})
	var want: int = recipe.output_count
	var left: int = InventoryService.add_item(recipe.output_item_id, want)
	if left > 0:
		var added: int = want - left
		if added > 0:
			InventoryService.remove_item(recipe.output_item_id, added)
		for r in removed:
			InventoryService.add_item(str(r["id"]), int(r["count"]))
		return false
	return true
