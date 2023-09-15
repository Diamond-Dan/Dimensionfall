extends Node

@export var health: float
@export var current_health: float
@export var moveSpeed: float
@export var sightRange: float
@export var senseRange: float
@export var hearingRange: float

# Called when the node enters the scene tree for the first time.
func _ready():
	current_health = health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
