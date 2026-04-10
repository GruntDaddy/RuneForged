extends Resource
class_name RecipeIngredient

@export var item_id: String = ""
@export_range(1, 999, 1) var count: int = 1
