extends Node

#This script is loaded in to the helper.gd autoload singleton
#It can be accessed trough helper.save_helper
#This scipt provides functions to help transitioning between levels
#It has functions to save the current level and the location of items, enemies and tiles
#It also has functions to load saved data and place the items, enemies and tiles on the map

var current_save_folder: String = ""

# Function to save the current level state
func save_current_level(global_pos: Vector2) -> void:
	var dir = DirAccess.open(current_save_folder)
	var map_folder = "map_x" + str(global_pos.x) + "_y" + str(global_pos.y)
	var target_folder = current_save_folder+ "/" + map_folder
	if !dir.dir_exists(map_folder):
		if !dir.make_dir(map_folder) == OK:
			print_debug("Failed to create a folder for the current map")
			return
	
	save_map_data(target_folder)
	save_enemy_data(target_folder)
	save_item_data(target_folder)

#Creates a new save folder. The name of this folder will be the current date and time
#This is to make sure it is unique. The folder name is stored in order to perform
#save and load actions. Also, the map seed is created and stored
func create_new_save():
	var dir = DirAccess.open("user://")
	var unique_folder_path := "save/" + Time.get_datetime_string_from_system()
	var sanitized_path = unique_folder_path.replace(":","")
	if dir.make_dir_recursive(sanitized_path) == OK:
		current_save_folder = "user://" + sanitized_path
		Helper.json_helper.write_json_file(current_save_folder + "/game.json",\
		JSON.stringify({"mapseed": randi()}))
	else:
		print_debug("Failed to create a unique folder for the demo.")

#Save the type and position of all enemies on the map
func save_enemy_data(target_folder: String) -> void:
	var enemyData: Array = []
	var defaultEnemy: Dictionary = {"enemyid": "enemy1", \
	"global_position_x": 0, "global_position_y": 0, "global_position_z": 0}
	var mapEnemies = get_tree().get_nodes_in_group("Enemies")
	var newEnemyData: Dictionary
	for enemy in mapEnemies:
		enemy.remove_from_group("Enemies")
		newEnemyData = defaultEnemy.duplicate()
		newEnemyData["global_position_x"] = enemy.global_position.x
		newEnemyData["global_position_y"] = enemy.global_position.y
		newEnemyData["global_position_z"] = enemy.global_position.z
		enemyData.append(newEnemyData.duplicate())
		enemy.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/enemies.json",\
	JSON.stringify(enemyData))

#Save the type and position of all enemies on the map
func save_item_data(target_folder: String) -> void:
	var itemData: Array = []
	var defaultitem: Dictionary = {"itemid": "item1", \
	"global_position_x": 0, "global_position_y": 0, "global_position_z": 0}
	var mapitems = get_tree().get_nodes_in_group("mapitems")
	var newitemData: Dictionary
	for item in mapitems:
		item.remove_from_group("mapitems")
		newitemData = defaultitem.duplicate()
		newitemData["global_position_x"] = item.global_position.x
		newitemData["global_position_y"] = item.global_position.y
		newitemData["global_position_z"] = item.global_position.z
		itemData.append(newitemData.duplicate())
		item.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/items.json",\
	JSON.stringify(itemData))

#The current state of the map is saved to disk
#Starting from the bottom level (-10), loop over every level
#Not every level is fully populated with blocks, so we need 
#to use the position of the block to store the map information
#If the level is fully populated by blocks, it will save all 
#the blocks with a value in the "texture" field
#If the level is not fully populated (for example, the level only contains
#the walls of a house), we check every possible position where a block
#could be and check if the position matches the position of the first
#child in the level. If it matches, we move on to the next child.
#If it does not match, we save information about the empty block instead.
#If a level has no children, it will remain an empty array []
func save_map_data(target_folder: String) -> void:
	var level_width : int = 32
	var level_height : int = 32
	var mapData: Dictionary = {"mapwidth": 32, "mapheight": 32, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}
	#During map generation, the levels were added to the maplevels group
	var tree: SceneTree = get_tree()
	var mapLevels = tree.get_nodes_in_group("maplevels")
	var block: StaticBody3D
	var current_block: int = 0
	var level_y: int = 0
	var textureName: String = ""
	var level_block_count: int = 0
	for level: Node3D in mapLevels:
		#The level will be destroyed after saving so we remove them from the group
		level.remove_from_group("maplevels")
		#The bottom level will have y set at -10. The first item in the mapData
		#array will be 0 so in this way we add the levels fom -10 to 10
		level_y = int(level.global_position.y+10)
		level_block_count = level.get_child_count()
		if level_block_count > 0:
			current_block = 0
			# Loop over every row one by one
			for h in level_height:
				# this loop will process blocks from West to East
				for w in level_width:
					block = level.get_child(current_block)
					if block.global_position.z == h and block.global_position.x == w:
						mapData.levels[level_y].append({ "id": block.id,\
						"rotation": block.rotation_degrees.y })
						if current_block < level_block_count-1:
							current_block += 1
					else:
						mapData.levels[level_y].append({})
	#Overwrite the file if it exists and otherwise create it
	Helper.json_helper.write_json_file(target_folder + "/map.json", JSON.stringify(mapData))
