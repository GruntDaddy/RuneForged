extends RefCounted
class_name GamepadPromptLabels

## Short labels for interaction prompts (Xbox naming; readable on PlayStation too).

const BUTTON_LABELS: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-Up",
	JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Right",
	JOY_BUTTON_MISC1: "P1",
	16: "P2",
}

const AXIS_LABELS: Dictionary = {
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}


static func label_for_event(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		return String(BUTTON_LABELS.get(jb.button_index, "Btn%d" % int(jb.button_index)))
	if ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		return String(AXIS_LABELS.get(jm.axis, "Axis%d" % int(jm.axis)))
	return ""
