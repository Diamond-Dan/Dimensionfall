extends Node3D




var level_json_as_text

var level_levels : Array
var map_save_folder: String

var level_width : int = 32
var level_height : int = 32


@onready var defaultBlock: PackedScene = preload("res://Blocks/grass_001.tscn")
@export var defaultEnemy: PackedScene
@export var defaultItem: PackedScene
@export var level_manager : Node3D
@export var block_scenes : Array[PackedScene]
@export_file var default_level_json



# Called when the node enters the scene tree for the first time.
func _ready():
	generate_map()
	$"../NavigationRegion3D".bake_navigation_mesh()
	
func generate_map():
	map_save_folder = get_saved_map_folder()
	generate_level()
	generate_enemies()
	generate_items()
	
func get_saved_map_folder() -> String:
	var level_name: String = Helper.current_level_name
	var level_pos: Vector2 = Helper.current_level_pos
	var current_save_folder: String = Helper.save_helper.current_save_folder
	var dir = DirAccess.open(current_save_folder)
	var map_folder = "map_x" + str(level_pos.x) + "_y" + str(level_pos.y)
	var target_folder = current_save_folder+ "/" + map_folder
	if dir.dir_exists(map_folder):
		return map_folder
	return ""

func generate_enemies() -> void:
	if map_save_folder == "":
		return
	var enemiesArray = Helper.json_helper.load_json_array_file(map_save_folder + "/enemies.json")
	for enemy in enemiesArray:
		var newEnemy: CharacterBody3D = defaultEnemy.instantiate()
		newEnemy.global_position.x = enemy.global_position_x
		newEnemy.global_position.y = enemy.global_position_y
		newEnemy.global_position.z = enemy.global_position_z
		newEnemy.add_to_group("Enemies")
		get_tree().get_root().add_child(newEnemy)
		

func generate_items() -> void:
	if map_save_folder == "":
		return
	var itemsArray = Helper.json_helper.load_json_array_file(map_save_folder + "/items.json")
	for item in itemsArray:
		var newItem: CharacterBody3D = defaultItem.instantiate()
		newItem.global_position.x = item.global_position_x
		newItem.global_position.y = item.global_position_y
		newItem.global_position.z = item.global_position_z
		newItem.add_to_group("mapitems")
		get_tree().get_root().add_child(newItem)

func generate_level() -> void:
	var level_name: String = Helper.current_level_name
	var textureName: String = ""
	if level_name == "":
		get_level_json()
	else:
		if map_save_folder == "":
			get_custom_level_json("./Mods/Core/Maps/" + level_name)
		else:
			get_custom_level_json(map_save_folder + "/map.json")
	
	
	var level_number = 0
	#we need to generate level layer by layer starting from the bottom
	for level in level_levels:
		if level != []:
			var level_node = Node3D.new()
			level_node.add_to_group("maplevels")
			level_manager.add_child(level_node)
			level_node.global_position.y = level_number-10
			
			
			var current_block = 0
			
			# we will generate number equal to "layer_height" of horizontal rows of blocks
			for h in level_height:
				
				# this loop will generate blocks from West to East based on the tile number
				# in json file

				
				for w in level_width:
					
					# checking if we have tile from json in our block array containing packedscenes
					# of blocks that we need to instantiate.
					# If yes, then instantiate
					
#					if block_scenes[level["data"][current_block]-1]:
					if level[current_block]:
						textureName = level[current_block].texture
						if textureName != "":
#							var block : StaticBody3D
##							block = block_scenes[0].instantiate()
							var block = create_block_with_material(textureName)
													
							#var block: StaticBody3D = defaultBlock.instantiate()
							#if textureName in Gamedata.tile_materials:
								#var material = Gamedata.tile_materials[textureName]
								#block.update_texture(material)
	#						block = block_scenes[layer["data"][current_block]-1].instantiate()
							level_node.add_child(block)
							
							block.global_position.x = w
							#block.global_position.y = layer_number
							block.global_position.z = h
					current_block += 1
				
		level_number += 1
	

	
	# YEAH I KNOW THAT SHOULD BE ONE FUNCTION, BUT IT'S 2:30 AM and... I'm TIRED LOL
func get_level_json():
	var file = default_level_json
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict: Dictionary = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]
	level_width = json_as_dict["mapwidth"]
	level_width = json_as_dict["mapheight"]

func get_custom_level_json(level_path):
	var file = level_path
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]


#This function takes a filename and create a new instance of block_scenes[0] which is a StaticBody3D. It will then take the material from the material dictionary based on the provided filename and apply it to the instance of StaticBody3D. Lastly it will return the StaticBody3D.
func create_block_with_material(filename: String) -> StaticBody3D:
	var block: StaticBody3D = defaultBlock.instantiate()
	if filename in Gamedata.tile_materials:
		var material = Gamedata.tile_materials[filename]
		block.update_texture(material)
	return block

