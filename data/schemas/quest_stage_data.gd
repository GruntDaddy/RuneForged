extends Resource
class_name QuestStageData

@export var stage_id: String = ""
@export var title: String = ""
@export_multiline var journal_text: String = ""
@export var objectives: Array[QuestObjectiveData] = []
@export var dialogue_lines: PackedStringArray = PackedStringArray()
@export var toast_hints: PackedStringArray = PackedStringArray()
