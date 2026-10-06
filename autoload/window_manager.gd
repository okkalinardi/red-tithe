extends Node
## Toggles between windowed and fullscreen (F11). Works while paused.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var window: Window = get_window()
	if window.mode == Window.MODE_WINDOWED:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
