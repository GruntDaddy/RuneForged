extends Resource
class_name EnemyDropProfile

const _EnemyDropEntry = preload("res://data/schemas/enemy_drop_entry.gd")

@export var entries: Array[_EnemyDropEntry] = []
