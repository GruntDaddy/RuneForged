extends Resource
class_name SkillData

enum SkillCategory {
	GATHERING,
	COMBAT,
	CRAFTING,
	BUILDING,
	SURVIVAL,
	MISC,
}

@export var id: String = ""
@export var display_name: String = ""
@export_range(1, 120, 1) var max_level: int = 99
@export var skill_category: SkillCategory = SkillCategory.GATHERING
