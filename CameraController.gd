extends Camera2D

@export var follow_speed: float = 5.0
@export var look_ahead_distance: float = 100.0

var player: CharacterBody2D
var target_position: Vector2

func _ready():
	player = get_node("../Player")
	if player:
		global_position = player.global_position

func _process(delta):
	if player:
		var look_ahead = player.velocity.normalized() * look_ahead_distance
		target_position = player.global_position + look_ahead
		global_position = global_position.lerp(target_position, follow_speed * delta)