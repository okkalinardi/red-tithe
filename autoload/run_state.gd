extends Node
## State of the current run that outlives individual scenes: wave, gold, time.
##
## Player stats, skills and weapons live on the player, not here.

signal wave_changed(wave: int)
signal gold_changed(gold: int)

const TOTAL_WAVES: int = 10
## Waves 1-9 are timed. The final wave ends when the boss dies.
const WAVE_DURATION: float = 30.0

var wave: int = 0
var gold: int = 0
var kills: int = 0
## Seconds of gameplay this run. Stops while the tree is paused.
var elapsed_time: float = 0.0
var is_running: bool = false


func _ready() -> void:
	set_process(false)
	Events.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	elapsed_time += delta


func start_run() -> void:
	wave = 0
	gold = 0
	kills = 0
	elapsed_time = 0.0
	is_running = true
	set_process(true)
	wave_changed.emit(wave)
	gold_changed.emit(gold)


func end_run() -> void:
	is_running = false
	set_process(false)


func advance_wave() -> void:
	wave = mini(wave + 1, TOTAL_WAVES)
	wave_changed.emit(wave)


func is_final_wave() -> bool:
	return wave >= TOTAL_WAVES


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


## Returns false and leaves gold unchanged if the player cannot afford it.
func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func _on_enemy_died(_data: EnemyData, _position: Vector2) -> void:
	kills += 1
