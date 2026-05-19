extends RefCounted
class_name GamepadBindings

## Registers Xbox / PlayStation (SDL layout) events on the project InputMap.
## Godot maps both controller families to the same joy button and axis indices.

const DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.35
## Xbox paddle / PS extra button when exposed by SDL (not in all Godot JoyButton enums).
const JOY_PADDLE_TWO: JoyButton = (16 as JoyButton)

static var _applied: bool = false


static func apply() -> void:
	if _applied:
		return
	_applied = true

	_ensure_movement_sticks()
	_map_button("jump", JOY_BUTTON_A)
	_map_button("interact", JOY_BUTTON_X)
	_map_button("interact_secondary", JOY_BUTTON_Y)
	_map_button("interact_tertiary", JOY_BUTTON_RIGHT_SHOULDER)
	_map_button("interact_quaternary", JOY_BUTTON_LEFT_SHOULDER)
	_map_button("run", JOY_BUTTON_LEFT_STICK)
	_map_button("sneak_roll", JOY_BUTTON_B)
	_map_button("pause_menu", JOY_BUTTON_START)
	_map_button("character_menu", JOY_BUTTON_RIGHT_STICK)
	_map_button("inventory", JOY_BUTTON_BACK)
	_map_button("craft_menu", JOY_BUTTON_MISC1)
	_map_button("build_menu", JOY_PADDLE_TWO)
	_map_button("tool_axe", JOY_BUTTON_DPAD_UP)
	_map_button("tool_pickaxe", JOY_BUTTON_DPAD_LEFT)
	_map_button("tool_hands", JOY_BUTTON_DPAD_DOWN)
	_map_button("tool_fishing", JOY_BUTTON_DPAD_RIGHT)
	_map_trigger_axis("attack", JOY_AXIS_TRIGGER_RIGHT)
	_map_trigger_axis("block", JOY_AXIS_TRIGGER_LEFT)
	_map_trigger_axis("swim_down", JOY_AXIS_TRIGGER_LEFT)

	_ensure_action("build_rotate_cw")
	_ensure_action("build_rotate_ccw")
	_ensure_action("build_cancel")
	_ensure_action("modular_rotate_cw")
	_ensure_action("modular_rotate_ccw")
	_ensure_action("modular_floor_up")
	_ensure_action("modular_floor_down")
	_ensure_action("modular_demolish")
	_map_button("build_rotate_cw", JOY_BUTTON_RIGHT_SHOULDER)
	_map_button("build_rotate_ccw", JOY_BUTTON_LEFT_SHOULDER)
	_map_button("build_cancel", JOY_BUTTON_B)
	_map_button("modular_rotate_cw", JOY_BUTTON_RIGHT_SHOULDER)
	_map_button("modular_rotate_ccw", JOY_BUTTON_LEFT_SHOULDER)
	_map_button("modular_floor_up", JOY_BUTTON_DPAD_UP)
	_map_button("modular_floor_down", JOY_BUTTON_DPAD_DOWN)
	_map_button("modular_demolish", JOY_BUTTON_X)

	_map_ui_defaults()


static func _ensure_movement_sticks() -> void:
	_map_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_map_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_map_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_map_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)


static func _map_ui_defaults() -> void:
	_ensure_action("ui_accept")
	_ensure_action("ui_cancel")
	_map_button("ui_accept", JOY_BUTTON_A)
	_map_button("ui_cancel", JOY_BUTTON_B)
	_map_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_map_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_map_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_map_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)


static func _ensure_action(action: String, deadzone: float = DEADZONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


static func _map_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


static func _map_axis(action: String, axis: JoyAxis, axis_value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	ev.device = -1
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


static func _map_trigger_axis(action: String, axis: JoyAxis) -> void:
	_ensure_action(action, TRIGGER_DEADZONE)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = 1.0
	ev.device = -1
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


static func _action_has_event(action: String, probe: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and probe is InputEventJoypadButton:
			var eb := existing as InputEventJoypadButton
			var pb := probe as InputEventJoypadButton
			if eb.device == pb.device and eb.button_index == pb.button_index:
				return true
		if existing is InputEventJoypadMotion and probe is InputEventJoypadMotion:
			var em := existing as InputEventJoypadMotion
			var pm := probe as InputEventJoypadMotion
			if (
				em.device == pm.device
				and em.axis == pm.axis
				and is_equal_approx(em.axis_value, pm.axis_value)
			):
				return true
	return false
