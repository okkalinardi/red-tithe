extends Node
## Persists the between-run records (high score, best time) to user://.

const SAVE_PATH: String = "user://save.cfg"
const SECTION: String = "records"

var high_score: int = 0
## Fastest winning run in seconds. 0.0 means no win recorded yet.
var best_time: float = 0.0


func _ready() -> void:
	load_records()


func load_records() -> void:
	var config := ConfigFile.new()
	# A missing file is normal on first launch; keep the defaults.
	if config.load(SAVE_PATH) != OK:
		return
	high_score = config.get_value(SECTION, "high_score", 0)
	best_time = config.get_value(SECTION, "best_time", 0.0)


## Records a finished run. Returns true if either record was beaten.
## Best time only counts for winning runs.
func submit_run(score: int, time_seconds: float, victory: bool) -> bool:
	var improved: bool = false
	if score > high_score:
		high_score = score
		improved = true
	if victory and (best_time <= 0.0 or time_seconds < best_time):
		best_time = time_seconds
		improved = true
	if improved:
		_save_records()
	return improved


func _save_records() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "high_score", high_score)
	config.set_value(SECTION, "best_time", best_time)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_error("Could not write %s: %s" % [SAVE_PATH, error_string(error)])
