extends Node

var current_scene: PackedScene = null

func _ready():
	change_scene("res://ui/menus/main_menu.tscn")

func change_scene(path):
	if current_scene != null:
		call_deferred("_end_current_scene")
	
	var new_scene = load(path)
	current_scene = new_scene
	get_tree().change_scene_to_packed(new_scene)

func _end_current_scene():
	current_scene = null
