extends Node

signal game_started
signal game_over
signal player_detected
signal player_lost

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.PLAYING
var survival_time: float = 0.0

func _ready():
	emit_signal("game_started")

func _process(delta):
	if current_state == GameState.PLAYING:
		survival_time += delta

func pause_game():
	current_state = GameState.PAUSED
	get_tree().paused = true

func resume_game():
	current_state = GameState.PLAYING
	get_tree().paused = false

func end_game():
	current_state = GameState.GAME_OVER
	emit_signal("game_over")

func get_survival_time() -> float:
	return survival_time
