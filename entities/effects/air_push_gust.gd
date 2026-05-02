extends Node3D

## Brief directional gust visual for Air Push (lvl 1).


func _ready() -> void:
	var L1 := OmniLight3D.new()
	L1.light_energy = 2.6
	L1.light_color = Color(0.72, 0.92, 1.0)
	L1.omni_range = 2.2
	L1.omni_attenuation = 0.45
	L1.shadow_enabled = false
	add_child(L1)
	var L2 := OmniLight3D.new()
	L2.position = Vector3(0, 0, 0.4)
	L2.light_energy = 1.4
	L2.light_color = Color(0.9, 0.95, 1.0)
	L2.omni_range = 1.5
	L2.shadow_enabled = false
	add_child(L2)
	var tw := get_tree().create_timer(0.28, true, false, true)
	tw.timeout.connect(queue_free)
