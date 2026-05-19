extends Resource
class_name QuestData

@export var id: String = ""
@export var title: String = ""
@export_multiline var summary: String = ""
@export var stages: Array[QuestStageData] = []
