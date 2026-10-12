class_name PhysicsLayers
extends Object
## Bit values of the 2D physics layers named in Project Settings.
## Use these instead of bare numbers: [code]mask = PhysicsLayers.ENEMY[/code].

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const ENEMY: int = 1 << 2
const PLAYER_ATTACK: int = 1 << 3
const ENEMY_ATTACK: int = 1 << 4
const PICKUP: int = 1 << 5
