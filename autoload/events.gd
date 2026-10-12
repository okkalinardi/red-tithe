extends Node
## Global signal bus for events that cross system boundaries.
##
## Emit from the system that owns the event, connect from anywhere:
## [codeblock]
## Events.wave_started.emit(3)
## Events.wave_started.connect(_on_wave_started)
## [/codeblock]
## State that an autoload owns (gold, wave number) is signalled by that
## autoload instead - see [RunState].

@warning_ignore("unused_signal")
signal wave_started(wave: int)
@warning_ignore("unused_signal")
signal wave_completed(wave: int)
@warning_ignore("unused_signal")
signal shop_opened
@warning_ignore("unused_signal")
signal shop_closed
@warning_ignore("unused_signal")
signal player_died
## Emitted once for every level the player gains.
@warning_ignore("unused_signal")
signal player_leveled_up(level: int)
## Emitted when an enemy is killed (not when it is despawned). The enemy node
## is pooled and may be reused at once, so only its data and position are sent.
@warning_ignore("unused_signal")
signal enemy_died(data: EnemyData, position: Vector2)
@warning_ignore("unused_signal")
signal boss_defeated
@warning_ignore("unused_signal")
signal run_ended(victory: bool)
