extends Node3D

## Tiny omnidirectional flash at world impact; cheap default when no custom VFX scene is set.


func _ready() -> void:
	var L := OmniLight3D.new()
	L.light_energy = 2.2
	L.omni_range = 1.85
	L.omni_attenuation = 0.55
	L.light_color = Color(1, 0.78, 0.38)
	L.shadow_enabled = false
	add_child(L)
	var tw := get_tree().create_timer(0.09, true, false, true)
	tw.timeout.connect(queue_free)
