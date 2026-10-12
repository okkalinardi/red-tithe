class_name GameOverPanel
extends CanvasLayer
## The plain end-of-run panel: death or victory, a few numbers, Restart.
## The full results screen with run stats is a later task.

signal restart_requested

@export var death_title: String = "YOU DIED"
@export var victory_title: String = "VICTORY"

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	# Works while the game is paused behind it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())


func show_result(victory: bool, wave: int, wave_count: int, seconds: float, kills: int, level: int) -> void:
	_title.text = victory_title if victory else death_title
	var whole: int = floori(seconds)
	_summary.text = "\n".join(PackedStringArray([
		"Wave %d/%d" % [wave, wave_count],
		"Time %d:%02d" % [floori(seconds / 60.0), whole % 60],
		"Kills %d" % kills,
		"Level %d" % level,
	]))
	visible = true
	_restart_button.grab_focus()


func is_open() -> bool:
	return visible
