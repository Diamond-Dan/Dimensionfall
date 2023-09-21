extends Node2D

var weapon
var magazine
var ammo

var current_ammo : int
var max_ammo : int

signal ammo_changed

@export var projectiles: NodePath
@export var bullet_speed: float
@export var bullet_damage: float
@export var cooldown = 0.25
@export var bullet_scene: PackedScene

@export var bullet_line_scene: PackedScene

@export var attack_cooldown : Timer
@export var reload_timer : Timer

var damage = 25


func _input(event):
	
	
	if event.is_action_pressed("reload_weapon"):
		reload_timer.start()
	
	
	if event.is_action_pressed("click") && General.is_mouse_outside_HUD && General.is_allowed_to_shoot:

#		var space_state = get_world_2d().direct_space_state
#		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (get_global_mouse_position() - global_position).normalized() * 10000 , pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1),[self])
#
#		var result = space_state.intersect_ray(query)
#
#		if result:
#			print("hit")
#			var line = bullet_line_scene.instantiate()
#			get_node(projectiles).add_child(line)
#			line.add_point(global_position)
#			line.add_point(result.position)
#
#			if result.collider.has_method("_get_hit"):
#				result.collider._get_hit(damage)
		if attack_cooldown.is_stopped() && current_ammo > 0 && reload_timer.is_stopped():
			attack_cooldown.start()
			current_ammo -= 1
			ammo_changed.emit(current_ammo, max_ammo)
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (get_global_mouse_position() - global_position).normalized() * 10000 , pow(2, 1-1) + pow(2, 2-1) + pow(2, 3-1),[self])

			var result = space_state.intersect_ray(query)
			
			if result:
				print("hit")
				var line = bullet_line_scene.instantiate()
				get_node(projectiles).add_child(line)
				line.add_point(global_position)
				line.add_point(result.position)
				
				if result.collider.has_method("_get_hit"):
					result.collider._get_hit(damage)



#		var bullet = bullet_scene.instantiate()
#		bullet.speed = bullet_speed
#		bullet.damage = bullet_damage
#		get_node(projectiles).add_child(bullet)
#		bullet.global_position = global_position
#		#bullet.rotation = (get_global_mouse_position() - global_position).normalized()
#		bullet.direction = (get_global_mouse_position() - global_position).normalized()

# Called when the node enters the scene tree for the first time.
func _ready():
	weapon = ItemManager.weapon
	magazine = ItemManager.magazine
	ammo = ItemManager.ammo
	
	max_ammo = int(magazine["max_ammo"])
	current_ammo = max_ammo
	
	ammo_changed.emit(current_ammo, max_ammo)
	
	attack_cooldown.wait_time = float(weapon["firing_speed"])
	reload_timer.wait_time = float(weapon["reload_speed"])
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_reload_time_timeout():
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
