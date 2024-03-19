class_name Chunk
extends Node3D


# This script is it's own class and is not assigned to any particular node
# You can call Chunk.new() to create a new instance of this class
# This script will manage the internals of a map chunk
# A chunk is made up of blocks, slopes, furniture and mobs
# The first time a chunk is loaded, it will be from a map definition
# Each time after that, it will load whatever whas saved when the player exited the map
# When the player exits the map, the chunk will get saved so it can be loaded later
# During the game chunks will be loaded and unloaded to improve performance
# A chunk is defined by 21 levels and each level can potentially hold 32x32 blocks
# On top of the blocks we spawn mobs and furniture
# Loading and unloading of chunks is managed by levelGenerator.gd

# Reference to the level manager. Some nodes that could be moved to other chunks should be parented to this
var level_manager : Node3D
var level_generator : Node3D

var level_width : int = 32
var level_height : int = 32
var _levels: Array[ChunkLevel] = [] # The level nodes that hold block nodes
var _mapleveldata: Array = [] # Holds the data for each level in this chunk
# This is a class variable to track block positions and data. It will contain:
# The position represented by a Vector3 in local coordinates
# The rotation represented by an int in degrees (0-360)
# The tilejson represented by a dictionary. This contains the id of the tile
var block_positions = {}
var chunk_data: Dictionary # The json data that defines this chunk
var processed_level_data: Dictionary = {}
var mutex: Mutex = Mutex.new()
var thread: Thread
var mypos: Vector3
var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh = NavigationMesh.new()
var source_geometry_data: NavigationMeshSourceGeometryData3D
var initialized_block_count: int = 0
var generation_task: int

signal chunk_unloaded


func _ready():
	chunk_unloaded.connect(_finish_unload)
	source_geometry_data = NavigationMeshSourceGeometryData3D.new()
	setup_navigation()
	transform.origin = Vector3(mypos)
	add_to_group("chunks")
	initialize_chunk_data()


func initialize_chunk_data():
	initialized_block_count = 0
	if chunk_data.has("id"): # This chunk is created for the first time
		#This contains the data of one segment, loaded from maps.data, for example generichouse.json
		var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
			Gamedata.data.maps.dataPath + chunk_data.id)
		_mapleveldata = mapsegmentData.levels
		generate_new_chunk()
	else: # This chunk is created from previously saved data
		#_mapleveldata = chunk_data.maplevels
		#WorkerThreadPool.add_task(generate_saved_chunk)
		#generation_task = WorkerThreadPool.add_task(generate_saved_chunk)
		#WorkerThreadPool.wait_for_task_completion(generation_task)
		generate_saved_chunk()


func generate_new_chunk():
	#thread = Thread.new()
	#thread.start(create_block_position_dictionary_new)
	#create_block_position_dictionary_new_finished()
	block_positions = create_block_position_dictionary_new_arraymesh()
	thread = Thread.new()
	thread.start(generate_chunk_mesh)
	#generate_chunk_mesh()


func generate_chunk_mesh_finished():
	# Wait for the thread to complete, and get the returned value.
	if is_instance_valid(thread) and thread.is_started():
		mutex.lock()
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
		#var processed_levels: Array = processed_level_data.lvl.duplicate()
		mutex.unlock()
	if chunk_data.has("id"): # This chunk is created for the first time
		process_level_data_finished()
	else:
		for item: Dictionary in chunk_data.items:
			add_item_to_map(item)
		thread = Thread.new()
		thread.start(add_furnitures_to_map.bind(chunk_data.furniture.duplicate()))
	

func process_level_data_finished():
	# Wait for the thread to complete, and get the returned value.
	#mutex.lock()
	#processed_level_data = thread.wait_to_finish()
	#thread = null # Threads are reference counted, so this is how we free them.
	##var processed_levels: Array = processed_level_data.lvl.duplicate()
	#mutex.unlock()
	processed_level_data = process_level_data()
	thread = Thread.new()
	thread.start(add_furnitures_to_new_block)
	#add_furnitures_to_new_block()



func process_level_data():
	var level_number = 0
	var tileJSON: Dictionary = {}
	var proc_lvl_data: Dictionary = {"furn": [],"mobs": []}

	for level in _mapleveldata:
		if level != []:
			var y: int = level_number - 10
			var current_block = 0
			for h in range(level_height):
				for w in range(level_width):
					if level[current_block]:
						tileJSON = level[current_block]
						if tileJSON.has("id") and tileJSON.id != "":
							if tileJSON.has("mob"):
								proc_lvl_data.mobs.append({"json":tileJSON.mob, "pos":Vector3(w,y+1.5,h)})
							if tileJSON.has("furniture"):
								var furniturjson = tileJSON.furniture
								proc_lvl_data.furn.append({"json":furniturjson, "pos":Vector3(w,y+0.5,h)})
					current_block += 1
		level_number += 1
	return proc_lvl_data


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with new mapdata
func create_block_position_dictionary_new_arraymesh() -> Dictionary:
	var new_block_positions:Dictionary = {}
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level != []:
			for h in range(level_height):
				for w in range(level_width):
					var current_block_index = h * level_width + w
					if level[current_block_index]:
						var tileJSON = level[current_block_index]
						if tileJSON.has("id") and tileJSON.id != "":
							var block_position_key = str(w) + "," + str(level_index-10) + "," + str(h)
							# We only save the data we need, exluding mob and furniture data
							new_block_positions[block_position_key] = {
								"id": tileJSON.id,
								"rotation": tileJSON.get("rotation", 0)
							}
	#create_block_position_dictionary_new_finished.call_deferred()
	return new_block_positions


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with previously saved chunk data
func create_block_position_dictionary_loaded() -> Dictionary:
	var new_block_positions:Dictionary = {}
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level.blocks != []:
			for blk in level.blocks:
				if blk.has("id") and not blk.id == "":
					var key = str(blk.block_x) + "," + str(level.map_y) + "," + str(blk.block_z)
					new_block_positions[key] = true
	#create_block_position_dictionary_loaded_finished.call_deferred()
	return new_block_positions


func create_block_position_dictionary_loaded_finished():
	#mutex.lock()
	## Wait for the thread to complete, and get the returned value.
	#block_positions = thread.wait_to_finish()
	#thread = null # Threads are reference counted, so this is how we free them.
	#mutex.unlock()
	block_positions = create_block_position_dictionary_loaded()


# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_chunk() -> void:
	#thread = Thread.new()
	#thread.start(create_block_position_dictionary_loaded)
	#create_block_position_dictionary_loaded_finished()
	block_positions = chunk_data.block_positions
	thread = Thread.new()
	thread.start(generate_chunk_mesh)
	#generate_chunk_mesh()
	#for item: Dictionary in chunk_data.items:
		#add_item_to_map(item)
	#thread = Thread.new()
	#thread.start(add_furnitures_to_map.bind(chunk_data.furniture.duplicate()))
	#add_furnitures_to_map(chunk_data.furniture.duplicate())


# When a map is loaded for the first time we spawn the mob on the block
func add_block_mobs():
	if not processed_level_data.has("mobs"):
		return
	mutex.lock()
	var mobdatalist = processed_level_data.mobs.duplicate()
	mutex.unlock()
	for mobdata: Dictionary in mobdatalist:
		var newMob: CharacterBody3D = Mob.new()
		# Pass the position and the mob json to the newmob and have it construct itself
		newMob.construct_self(mypos+mobdata.pos, mobdata.json)
		level_manager.add_child.call_deferred(newMob)
	add_block_mobs_finished.call_deferred()


func add_block_mobs_finished():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.


# When a map is loaded for the first time we spawn the furniture on the block
func add_furnitures_to_new_block():
	mutex.lock()
	var furnituredata = processed_level_data.furn.duplicate()
	mutex.unlock()
	var total_furniture = furnituredata.size()
	 # Ensure we at least get 1 to avoid division by zero
	var delay_every_n_furniture = max(1, total_furniture / 15)

	for i in range(total_furniture):
		var furniture = furnituredata[i]
		var furnituremapjson: Dictionary = furniture.json
		var furniturepos: Vector3 = furniture.pos
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
			Gamedata.data.furniture, furnituremapjson.id)
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = FurniturePhysics.new()
			furniturepos.y += 0.2 # Make sure it's not in a block and let it fall
		else:
			newFurniture = FurnitureStatic.new()

		newFurniture.construct_self(mypos+furniturepos, furnituremapjson)
		level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n blocks, evenly spreading the delay
		if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(100)
	add_furnitures_to_new_block_finished.call_deferred()


func add_furnitures_to_new_block_finished():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	thread = Thread.new()
	thread.start(add_block_mobs)
	#add_block_mobs()


# Saves all of the maplevels to disk
# A maplevel is one 32x32 layer at a certain x,y and z position
# This layer will contain 1024 blocks
func get_map_data() -> Array:
	var maplevels: Array = []
	mutex.lock()
	var mylevels = _levels.duplicate()
	mutex.unlock()

	# Loop over the levels in the map
	for level: Node3D in mylevels:
		level.remove_from_group.call_deferred("maplevels")
		var level_node_data: Array = []
		var level_node_dict: Dictionary = {}
		mutex.lock()
		level_node_dict["map_y"] = level.levelposition.y
		var blocklevellist: Array = level.blocklist.duplicate()
		mutex.unlock()
		level_node_dict["blocks"] = level_node_data

		# Loop over the blocks in the level
		for block in blocklevellist:
			var block_data: Dictionary = {}
			block_data["id"] = block.json.id
			block_data["rotation"] = int(block.json.blockrotation)
			block_data["block_x"] = block.w
			block_data["block_z"] = block.h
			level_node_data.append(block_data)
		maplevels.append(level_node_dict)
	return maplevels


func get_furniture_data() -> Array:
	var furnitureData: Array = []
	var mapFurniture = get_tree().get_nodes_in_group("furniture")
	var newFurnitureData: Dictionary
	var newRot: int
	var furniturepos: Vector3
	for furniture in mapFurniture:
		# We check if the furniture is a valid instance. Sometimes it isn't
		# This might be because two chunks try to unload the furniture?
		# We might need more work on _is_object_in_range
		if is_instance_valid(furniture):
			if furniture is FurniturePhysics:
				mutex.lock()
				newRot = furniture.last_rotation
				furniturepos = furniture.last_position
				#print_debug("removing furniture with posdition: ", furniturepos)
				mutex.unlock()
			else: # It's FurnitureStatic
				mutex.lock()
				newRot = furniture.get_my_rotation()
				furniturepos = furniture.furnitureposition
				mutex.unlock()
			# Check if furniture's position is within the desired range
			# It's possible some furniture is still spawning and have their position be 0,0,0
			# We do not want to save that furniture, just the ones at the other positions
			if _is_object_in_range(furniturepos) and not furniturepos == Vector3(0,0,0):
				furniture.remove_from_group.call_deferred("furniture")
				newFurnitureData = {
					"id": furniture.furnitureJSON.id,
					"moveable": furniture is FurniturePhysics,
					"global_position_x": furniturepos.x,
					"global_position_y": furniturepos.y,
					"global_position_z": furniturepos.z,
					"rotation": newRot,  # Save the Y-axis rotation
				}
				furnitureData.append(newFurnitureData.duplicate())
				furniture.queue_free.call_deferred()
		else:
			print_debug("Tried to get data from furniture, but it's null!")
	return furnitureData


# We check if the furniture or mob or item's position is inside this chunk on the x and z axis
func _is_object_in_range(objectposition: Vector3) -> bool:
		return objectposition.x >= mypos.x and \
		objectposition.x <= mypos.x + level_width and \
		objectposition.z >= mypos.z and \
		objectposition.z <= mypos.z + level_height


# Save all the mobs and their current stats to the mobs file for this map
func get_mob_data() -> Array:
	var mobData: Array = []
	var mapMobs = get_tree().get_nodes_in_group("mobs")
	var newMobData: Dictionary
	for mob in mapMobs:
		# Check if furniture's position is within the desired range
		if _is_object_in_range(mob.last_position):
			mob.remove_from_group.call_deferred("mobs")
			newMobData = {
				"id": mob.mobJSON.id,
				"global_position_x": mob.last_position.x,
				"global_position_y": mob.last_position.y,
				"global_position_z": mob.last_position.z,
				"rotation": mob.last_rotation,
				"melee_damage": mob.melee_damage,
				"melee_range": mob.melee_range,
				"health": mob.health,
				"current_health": mob.current_health,
				"move_speed": mob.moveSpeed,
				"current_move_speed": mob.current_move_speed,
				"idle_move_speed": mob.idle_move_speed,
				"current_idle_move_speed": mob.current_idle_move_speed,
				"sight_range": mob.sightRange,
				"sense_range": mob.senseRange,
				"hearing_range": mob.hearingRange
			}
			mobData.append(newMobData.duplicate())
			mob.queue_free.call_deferred()
	return mobData


#Save the type and position of all mobs on the map
func get_item_data() -> Array:
	var itemData: Array = []
	var myItem: Dictionary = {
		"itemid": "item1", 
		"global_position_x": 0, 
		"global_position_y": 0, 
		"global_position_z": 0, 
		"inventory": []
	}
	var mapitems = get_tree().get_nodes_in_group("mapitems")
	var newitemData: Dictionary
	for item in mapitems:
		if _is_object_in_range(item.containerpos):
			item.remove_from_group("mapitems")
			newitemData = myItem.duplicate()
			newitemData["global_position_x"] = item.containerpos.x
			newitemData["global_position_y"] = item.containerpos.y
			newitemData["global_position_z"] = item.containerpos.z
			newitemData["inventory"] = item.inventory.serialize()
			itemData.append(newitemData.duplicate())
			item.queue_free.call_deferred()
	return itemData


# Called when a save is loaded
func add_mobs_to_map() -> void:
	mutex.lock()
	var mobdata: Array = chunk_data.mobs.duplicate()
	mutex.unlock()
	for mob: Dictionary in mobdata:
		var newMob: CharacterBody3D = Mob.new()
		# Put the mob back where it was when the map was unloaded
		var mobpos: Vector3 = Vector3(mob.global_position_x,mob.global_position_y,mob.global_position_z)
		newMob.construct_self(mobpos, mob)
		level_manager.add_child.call_deferred(newMob)
	add_mobs_to_map_finished.call_deferred()


func add_mobs_to_map_finished():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.


# Called by generate_items function when a save is loaded
func add_item_to_map(item: Dictionary):
	var newItem: ContainerItem = ContainerItem.new()
	newItem.add_to_group("mapitems")
	var pos: Vector3 = Vector3(item.global_position_x,item.global_position_y,item.global_position_z)
	newItem.construct_self(pos)
	level_manager.add_child.call_deferred(newItem)
	newItem.inventory.deserialize(item.inventory)


# Adds furniture that has been loaded from previously saved data
func add_furnitures_to_map(furnitureDataArray: Array):
	var newFurniture: Node3D
	
	var total_furniture = furnitureDataArray.size()
	 # Ensure we at least get 1 to avoid division by zero
	#var delay_every_n_furniture = max(1, total_furniture / 15)
	var delay_every_n_furniture = max(1, int(total_furniture / 15))
	for i in range(total_furniture):
		var furnitureData = furnitureDataArray[i]
		mutex.lock()
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(
		Gamedata.data.furniture, furnitureData.id)
		mutex.unlock()

		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = FurniturePhysics.new()
		else:
			newFurniture = FurnitureStatic.new()

		# We can't set it's position until after it's in the scene tree 
		# so we only save the position to a variable and pass it to the furniture
		var furniturepos: Vector3 =  Vector3(furnitureData.global_position_x,furnitureData.global_position_y,furnitureData.global_position_z)
		newFurniture.construct_self(furniturepos,furnitureData)
		level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n furniture, evenly spreading the delay
		if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last furniture if the total_furniture is not perfectly divisible by delay_every_n_furniture
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(100)
	
	add_furnitures_to_map_finised.call_deferred()


func add_furnitures_to_map_finised():
	if is_instance_valid(thread) and thread.is_started():
		if thread.is_alive():
			print_debug("The thread is still alive, blocking calling thread")
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	thread = Thread.new()
	thread.start(add_mobs_to_map)
	#add_block_mobs()


# Returns all the chunk data used for saving and loading
func get_chunk_data() -> Dictionary:
	var chunkdata: Dictionary = {}
	mutex.lock()
	chunkdata.chunk_x = mypos.x
	chunkdata.chunk_z = mypos.z
	mutex.unlock()
	#chunkdata.maplevels = get_map_data()
	chunkdata.block_positions = block_positions.duplicate()
	chunkdata.furniture = get_furniture_data()
	chunkdata.mobs = get_mob_data()
	chunkdata.items = get_item_data()
	#finish_unload_chunk.call_deferred()
	return chunkdata



func unload_chunk():
	print_debug("Starting unload chunk")
	if is_instance_valid(thread) and thread.is_started():
	# Wait for the thread to complete, and get the returned value.
		mutex.lock()
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
		#var processed_levels: Array = processed_level_data.lvl.duplicate()
		mutex.unlock()
	#thread = Thread.new()
	#thread.start(get_chunk_data)
	#get_chunk_data()
	finish_unload_chunk.call_deferred()
	

func finish_unload_chunk():
	print_debug("finish unload chunk")
	var chunkdata: Dictionary
	mutex.lock()
	if is_instance_valid(thread) and thread.is_started():
		chunkdata = thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
		
	chunkdata = get_chunk_data()
	var chunkposition: Vector2 = Vector2(int(chunkdata.chunk_x/32),int(chunkdata.chunk_z/32))
	Helper.loaded_chunk_data.chunks[chunkposition] = chunkdata
	mutex.unlock()
	
	# Queue all levels for deletion, freeing all children (blocks) first.
	for level in _levels:
		# Iterate through all children of the level and queue them for deletion
		for child in level.get_children():
			child.queue_free()
		# Now that all children have been queued for deletion, queue the level itself
		#level.queue_free()

	# Clear the _levels array since all levels are now queued for deletion.
	mutex.lock()
	_levels.clear()
	mutex.unlock()
	
	print_debug("emitting chunk unloaded")
	chunk_unloaded.emit()



# Adds triangles represented by 3 vertices to the navigation mesh data
# If a block is above another block, we make sure no plane is created in between
# For blocks we will create a square represented by 2 triangles
# The same goes for slopes, but 2 of the vertices are lowered to the ground
# keep in mind that after the navigationmesh is added to the navigationregion
# It will be shrunk by the navigation_mesh.agent_radius to prevent collisions
func add_mesh_to_navigation_data(blockposition: Vector3, blockrotation: int, blockshape: String):
	var block_global_position: Vector3 = blockposition# + mypos
	var blockrange: float = 0.5
	
	# Check if there's a block directly above the current block
	var above_key = str(blockposition.x) + "," + str(block_global_position.y + 1) + "," + str(blockposition.z)
	if block_positions.has(above_key):
		# There's a block directly above, so we don't add a face for the current block's top
		return

	if blockshape == "cube":
		# Top face of a block, the block size is 1x1x1 for simplicity.
		var top_face_vertices = PackedVector3Array([
			# First triangle
			Vector3(-blockrange, 0.5, -blockrange), # Top-left
			Vector3(blockrange, 0.5, -blockrange), # Top-right
			Vector3(blockrange, 0.5, blockrange), # Bottom-right
			# Second triangle
			Vector3(-blockrange, 0.5, -blockrange), # Top-left (repeated for the second triangle)
			Vector3(blockrange, 0.5, blockrange), # Bottom-right (repeated for the second triangle)
			Vector3(-blockrange, 0.5, blockrange)  # Bottom-left
		])
		# Add the top face as two triangles.
		mutex.lock()
		source_geometry_data.add_faces(top_face_vertices, Transform3D(Basis(), block_global_position))
		mutex.unlock()
	elif blockshape == "slope":
		# Define the initial slope vertices here. We define a set for each direction
		var vertices_north = PackedVector3Array([ #Facing north
			Vector3(-blockrange, 0.5, -blockrange), # Top front left
			Vector3(blockrange, 0.5, -blockrange), # Top front right
			Vector3(blockrange, -0.5, blockrange), # Bottom back right
			Vector3(-blockrange, -0.5, blockrange) # Bottom back left
		])
		var vertices_east = PackedVector3Array([
			Vector3(blockrange, 0.5, -blockrange), # Top back right
			Vector3(blockrange, 0.5, blockrange), # Top front right
			Vector3(-blockrange, -0.5, blockrange), # Bottom front left
			Vector3(-blockrange, -0.5, -blockrange) # Bottom back left
		])
		var vertices_south = PackedVector3Array([
			Vector3(blockrange, 0.5, blockrange), # Top front right
			Vector3(-blockrange, 0.5, blockrange), # Top front left
			Vector3(-blockrange, -0.5, -blockrange), # Bottom back left
			Vector3(blockrange, -0.5, -blockrange) # Bottom back right
		])
		var vertices_west = PackedVector3Array([
			Vector3(-blockrange, 0.5, blockrange), # Top front left
			Vector3(-blockrange, 0.5, -blockrange), # Top back left
			Vector3(blockrange, -0.5, -blockrange), # Bottom back right
			Vector3(blockrange, -0.5, blockrange) # Bottom front right
		])

		# We pick a direction based on the block rotation
		var blockrot: int = blockrotation
		var vertices
		match blockrot:
			90:
				vertices = vertices_north
			180:
				vertices = vertices_west
			270:
				vertices = vertices_south
			_:
				vertices = vertices_east

		# Define triangles for the slope
		var slope_faces = PackedVector3Array([
			vertices[0], vertices[1], vertices[2],  # Triangle 1: TFL, TFR, BBR
			vertices[0], vertices[2], vertices[3]   # Triangle 2: TFL, BBR, BBL
		])
		mutex.lock()
		source_geometry_data.add_faces(slope_faces, Transform3D(Basis(), block_global_position))
		mutex.unlock()


# Rotates the vertex passed in the parameter. Used to rotate slope data for the navigationmesh
func rotate_vertex(vertex: Vector3, degrees: int) -> Vector3:
	match degrees:
		90:
			return Vector3(-vertex.z, vertex.y, vertex.x)
		180:
			return Vector3(-vertex.x, vertex.y, -vertex.z)
		270:
			return Vector3(vertex.z, vertex.y, -vertex.x)
		_:
			return vertex


func _finish_unload():
	print_debug("unloading chunk")
	
	# Queue all levels for deletion, freeing all children (blocks) first.
	#for level in _levels:
		## Now that all children have been queued for deletion, queue the level itself
		#level.queue_free()
	# Finally, queue the chunk itself for deletion.
	queue_free.call_deferred()



# We update the navigationmesh for this chunk with data generated from the blocks
func update_navigation_mesh():
	NavigationMeshGenerator.bake_from_source_geometry_data(navigation_mesh, source_geometry_data)
	navigation_region.navigation_mesh = navigation_mesh



# Each chunk will have it's own navigationmesh, which will be joined automatically on the global map
func setup_navigation():
	navigation_mesh.cell_size = 0.1
	navigation_mesh.agent_height = 0.5
	# Remember that the navigation mesh will shrink if you increase the agent_radius
	# This will happen to prevent the agent from hugging obstacles a lot
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.agent_max_slope = 46
	# Create a new navigation region and set its transform based on mypos
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)
	NavigationServer3D.map_set_cell_size(get_world_3d().get_navigation_map(),0.1)


# This function creates a atlas texture which is a combination of the textures that we need
# for the blocks in this chunk. When there are more different blocks in the chunk, the atlas will
# be bigger. The atlas texture will be used by the rendering engine to render the right texture
# This function will also create a mapping of the texture and the coordinates in the atlas
# This will help to determine which block needs which coordinate on the atlas to display the right texture
func create_atlas() -> Dictionary:
	var material_to_blocks: Dictionary = {} # Dictionary to hold blocks organized by material
	var block_uv_map: Dictionary = {} # Dictionary to map block IDs to their UV coordinates in the atlas
	
	# Organize the materials we need into a dictionary
	for key: Dictionary in block_positions.keys():
		var block_data = block_positions[key]
		var material_id = str(block_data["id"]) # Key for material ID
		if not material_to_blocks.has(material_id):
			var sprite = Gamedata.get_sprite_by_id(Gamedata.data.tiles, material_id)
			if sprite:
				material_to_blocks[material_id] = sprite.albedo_texture

	# Calculate the atlas size needed
	var num_textures: int = material_to_blocks.keys().size()
	var atlas_dimension = int(ceil(sqrt(num_textures))) # Convert to int to ensure modulus operation works
	var texture_size = 128 # Assuming each texture is 128x128 pixels
	var atlas_pixel_size = atlas_dimension * texture_size

	# Create a large blank Image for the atlas
	var atlas_image = Image.create(atlas_pixel_size, atlas_pixel_size, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0)) # Transparent background

	# Step 3: Blit each texture onto the atlas and update block_uv_map
	var texposition = Vector2.ZERO
	var index = 0
	for material_id in material_to_blocks.keys():
		
		var texture: Image = material_to_blocks[material_id].get_image()
		
		var img: Image = texture.duplicate()
		if img.is_compressed():
			img.decompress() # Decompress if the image is compressed
		img.convert(Image.FORMAT_RGBA8) # Convert texture to RGBA8 format
		var dest_rect = Rect2(texposition, img.get_size())
		var used_rect: Rect2i = img.get_used_rect()
		
		if img.is_empty(): # Check if the image data is empty
			continue # Skip this texture as it's not loaded properly
		atlas_image.blit_rect(img, used_rect, dest_rect.position)

		# Calculate and store the UV offset and scale for this material
		var uv_offset = texposition / atlas_pixel_size
		var uv_scale = img.get_size() / float(atlas_pixel_size)
		block_uv_map[material_id] = {"offset": uv_offset, "scale": uv_scale}

		# Update position for the next texture
		index += 1
		if index % atlas_dimension == 0:
			texposition.x = 0
			texposition.y += texture_size
		else:
			texposition.x = (index % atlas_dimension) * texture_size

	# Convert the atlas Image to a Texture
	var atlas_texture = ImageTexture.create_from_image(atlas_image)
	return {"atlas_texture": atlas_texture, "block_uv_map": block_uv_map}


# This will add the following to the "arrays" parameter:
# arrays[ArrayMesh.ARRAY_VERTEX] = verts
# arrays[ArrayMesh.ARRAY_NORMAL] = normals
# arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
# arrays[ArrayMesh.ARRAY_INDEX] = indices
# This represents the data that will be used to create an arraymesh, which visualizes the blocks
# The block_uv_map is used to map the block id to the right uv coordinates on the atlas texture
func prepare_mesh_data(arrays: Array, block_uv_map: Dictionary):
	# Define a small margin to prevent seams
	var margin: float = 0.01

	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	# Assume a block size for the calculations
	var block_size: float = 1.0

	for key in block_positions.keys():
		var pos_array = key.split(",")
		var poslocal = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		
		# Adjust position based on the block size
		var pos = poslocal * block_size
		
		var block_data = block_positions[key]
		var material_id = str(block_data["id"])
		# Get the shape of the block
		var tileJSONData = Gamedata.get_data_by_id(Gamedata.data.tiles,block_data.id)
		var blockshape = tileJSONData.get("shape", "cube")
		
		# Calculate UV coordinates based on the atlas
		var uv_info = block_uv_map[material_id] if block_uv_map.has(material_id) else {"offset": Vector2(0, 0), "scale": Vector2(1, 1)}
		var uv_offset = Vector2(uv_info["offset"])#.to_vector2() # Convert to Vector2 if needed
		var uv_scale = Vector2(uv_info["scale"])#.to_vector2() # Convert to Vector2 if needed

		# Adjust the UVs to include the margin uniformly
		var top_face_uv = PackedVector2Array([
			(Vector2(0, 0) * uv_scale + Vector2(margin, margin)) + uv_offset,
			(Vector2(1, 0) * uv_scale + Vector2(-margin, margin)) + uv_offset,
			(Vector2(1, 1) * uv_scale + Vector2(-margin, -margin)) + uv_offset,
			(Vector2(0, 1) * uv_scale + Vector2(margin, -margin)) + uv_offset
		])
		var blockrotation: int = 0
		if chunk_data.has("id"): # This chunk is created for the first time, so we need to save 
			# the rotation to the block json dictionary
			blockrotation = get_block_rotation(blockshape, block_data.rotation)
			block_data["rotation"] = blockrotation
		else: # Rotation has been previously saved so we can use that
			blockrotation = block_data.rotation
		# After calculating and adding vertices to the mesh arrays
		# Call add_mesh_to_navigation_data for each block
		add_mesh_to_navigation_data(poslocal, blockrotation, blockshape)
		
		if blockshape == "cube":
			setup_cube(pos, blockrotation, verts, uvs, normals, indices, top_face_uv)
		elif blockshape == "slope":
			setup_slope(blockrotation, pos, verts, uvs, normals, indices, top_face_uv)
		
	arrays[ArrayMesh.ARRAY_VERTEX] = verts
	arrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrays[ArrayMesh.ARRAY_INDEX] = indices


# Creates the entire chunk including:
# - Mesh shape
# - Mesh texture
# - Navigation map
# - Colliders
func generate_chunk_mesh():
	# Create the atlas and get the atlas texture
	var atlas_output = create_atlas()
	var atlas_texture = atlas_output.atlas_texture
	var block_uv_map = atlas_output.block_uv_map

	# Process all blocks and create the mesh
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	prepare_mesh_data(arrays, block_uv_map)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create a new ShaderMaterial
	var shader_material = setup_material(atlas_texture)
	mesh.surface_set_material(0, shader_material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child.call_deferred(mesh_instance)
	
	# Create the static body for collision
	var static_body = StaticBody3D.new()
	static_body.disable_mode = CollisionObject3D.DISABLE_MODE_MAKE_STATIC
	# Set collision layer to layer 1 and 5
	static_body.collision_layer = 1 | (1 << 4) # Layer 1 is 1, Layer 5 is 1 << 4 (16), combined with bitwise OR
	# Set collision mask to layer 1
	static_body.collision_mask = 1 # Layer 1 is 1
	create_colliders(static_body)
	add_child.call_deferred(static_body)
	
	update_navigation_mesh.call_deferred()
	generate_chunk_mesh_finished.call_deferred()


func setup_cube(pos: Vector3, blockrotation: int, verts, uvs, normals, indices, top_face_uv):
	# Assume a block size for the calculations
	var half_block = 0.5
	var top_verts = [
		Vector3(-half_block, half_block, -half_block) + pos,
		Vector3(half_block, half_block, -half_block) + pos,
		Vector3(half_block, half_block, half_block) + pos,
		Vector3(-half_block, half_block, half_block) + pos
	]
	
	var rotated_top_verts = []
	for vertex in top_verts:
		rotated_top_verts.append(rotate_vertex_y(vertex - pos, blockrotation) + pos)

	verts.append_array(rotated_top_verts)
	uvs.append_array(top_face_uv)
	
	# Normals for the top face
	for _i in range(4):
		normals.append(Vector3(0, 1, 0))
	
	# Indices for the top face
	var base_index = verts.size() - 4
	indices.append_array([
		base_index, base_index + 1, base_index + 2,
		base_index, base_index + 2, base_index + 3
	])
	

func setup_slope(blockrotation: int, pos: Vector3, verts, uvs, normals, indices, top_face_uv):
	# Slope-specific vertices and UV mapping
	# Determine slope orientation and vertices based on blockrotation
	var slope_vertices: PackedVector3Array
	# Assume a block size for the calculations
	var half_block = 0.5
	match blockrotation:
		90:
			# Slope facing Facing north
			slope_vertices = PackedVector3Array([
				Vector3(-half_block, half_block, -half_block) + pos, # Top front left
				Vector3(half_block, half_block, -half_block) + pos,   # Top front right
				Vector3(half_block, -half_block, half_block) + pos,  # Bottom back right
				Vector3(-half_block, -half_block, half_block) + pos  # Bottom back left
			])
		180:
			# Slope facing Facing west
			slope_vertices = PackedVector3Array([
				Vector3(-half_block, half_block, half_block) + pos, # Top front left
				Vector3(-half_block, half_block, -half_block) + pos,   # Top front right
				Vector3(half_block, -half_block, -half_block) + pos,  # Bottom back right
				Vector3(half_block, -half_block, half_block) + pos  # Bottom back left
			])
		270:
			# Slope facing Facing south
			slope_vertices = PackedVector3Array([
				Vector3(half_block, half_block, half_block) + pos, # Top front left
				Vector3(-half_block, half_block, half_block) + pos,   # Top front right
				Vector3(-half_block, -half_block, -half_block) + pos,  # Bottom back right
				Vector3(half_block, -half_block, -half_block) + pos  # Bottom back left
			])
		_:
			# Slope facing Facing east
			slope_vertices = PackedVector3Array([
				Vector3(half_block, half_block, -half_block) + pos, # Top front left
				Vector3(half_block, half_block, half_block) + pos,   # Top front right
				Vector3(-half_block, -half_block, half_block) + pos,  # Bottom back right
				Vector3(-half_block, -half_block, -half_block) + pos  # Bottom back left
			])

	# Assuming the top_face_uv calculated for cubes applies here as well
	verts.append_array(slope_vertices)
	uvs.append_array(top_face_uv)  # Reuse the UV mapping for simplicity in this example
	
	# Normals for the slope's top face, assuming flat shading for simplicity
	var normal = Vector3(0, 1, 0)  # Adjust if your slope's top face orientation varies
	for _i in range(4):
		normals.append(normal)
	
	# Indices for the slope, similar to the cube but only for one triangular face
	var base_index = verts.size() - 4
	indices.append_array([
		base_index, base_index + 1, base_index + 2,
		base_index, base_index + 2, base_index + 3
	])


func setup_material(atlas_texture: ImageTexture) -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	# Setup shader code and parameters
	# Create a new Shader
	var shader = Shader.new()
	
	shader.set_code("""
	shader_type spatial;
	render_mode blend_mix,depth_draw_opaque;

	uniform sampler2D albedo_texture; // The texture image
	uniform vec4 albedo_color : source_color;
	uniform float cylinder_height = 5.0;
	uniform float cylinder_radius = 3.0;
	uniform float sphere_size = 5.0;
	global uniform vec3 player_pos; // This needs to be set from script

	varying vec3 world_vertex;

	void vertex() {
		world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}

	void fragment() {
		// Sample the albedo texture
		vec4 texture_color = texture(albedo_texture, UV);
		
		// Combine texture color with the albedo color uniform
		vec3 final_color = texture_color.rgb * albedo_color.rgb;

		// Compute the distance from the player position to the current fragment's position
		float dist_xz = distance(player_pos.xz, world_vertex.xz);
		float dist_y = max(world_vertex.y - player_pos.y, 0.0); // Distance above the player, not below

		// Compute the visibility based on the sphere size
		float visibility_xz = smoothstep(sphere_size, 0.0, dist_xz);
		float visibility_y = smoothstep(sphere_size, 0.0, dist_y);

		// Check if the fragment is above the player within the sphere radius
		if (world_vertex.y > player_pos.y+1.0 && dist_xz < sphere_size) {
			// Above the player within the sphere radius, apply visibility
			ALPHA = visibility_xz * visibility_y;
		} else {
			// Outside of the sphere radius or on/below the player's level, fully visible
			ALPHA = 1.0;
		}

		// Set the final albedo color and transparency
		ALBEDO = final_color;
	}



	""")
	
	# Assign the Shader to the ShaderMaterial# Assuming 'atlas_texture' is your Texture2D you want to use
	shader_material.set_shader_parameter('albedo_texture', atlas_texture)
	shader_material.shader = shader

	# Set the initial uniform values
	shader_material.set_shader_parameter('albedo_color', Color(1, 1, 1, 1)) # White color, fully opaque
	shader_material.set_shader_parameter('sphere_size', 3.0)
	shader_material.set_shader_parameter('albedo_texture', atlas_texture)
	return shader_material


# Takes the chunk static body and adds a collider for each block
# A cube and a slope will have different collider shapes
func create_colliders(static_body: StaticBody3D):
	# At the end of your generate_chunk_mesh function, after you've added the mesh instance:
	for key in block_positions.keys():
		var pos_array = key.split(",")
		var block_pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		var block_data = block_positions[key]
		var tileJSONData = Gamedata.get_data_by_id(Gamedata.data.tiles,block_data.id)
		var blockshape = tileJSONData.get("shape", "cube")
		static_body.add_child.call_deferred(_create_block_collider(block_pos, blockshape, block_data.rotation))


# Creates a collider for either a slope or a cube and puts it at the right place and rotation
func _create_block_collider(block_sub_position, shape: String, block_rotation: int) -> CollisionShape3D:
	var collider = CollisionShape3D.new()
	if shape == "cube":
		collider.shape = BoxShape3D.new()
		collider.set_transform.call_deferred(Transform3D(Basis(), block_sub_position))
	else: # It's a slope
		collider.shape = ConvexPolygonShape3D.new()
		collider.shape.points = [
			Vector3(0.5, 0.5, 0.5),
			Vector3(0.5, 0.5, -0.5),
			Vector3(-0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, -0.5),
			Vector3(-0.5, -0.5, -0.5)
		]
		# Apply rotation only for slopes
		# Set the rotation part of the Transform3D
		var rotation_transform = Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(block_rotation)), Vector3.ZERO)
		# Now combine rotation and translation in the transform
		collider.set_transform.call_deferred(rotation_transform.translated(block_sub_position))
	return collider


# Rotates a 3D vertex around the Y-axis
func rotate_vertex_y(vertex: Vector3, degrees: float) -> Vector3:
	var rad = deg_to_rad(degrees)
	var cos_rad = cos(rad)
	var sin_rad = sin(rad)
	return Vector3(
		cos_rad * vertex.x + sin_rad * vertex.z,
		vertex.y,
		-sin_rad * vertex.x + cos_rad * vertex.z
	)

# Assuming 'block_rotation' is the rotation angle in degrees returned by get_block_rotation
func rotate_vertices(vertices: Array, block_rotation: int, center: Vector3 = Vector3.ZERO) -> Array:
	var rotated_vertices = []
	var rad = deg_to_rad(block_rotation)
	var cos_rad = cos(rad)
	var sin_rad = sin(rad)
	
	for vertex in vertices:
		# Translate vertex to origin (if your center is not Vector3.ZERO, adjust accordingly)
		var v = vertex - center
		# Apply rotation around Y-axis
		var x_new = v.x * cos_rad - v.z * sin_rad
		var z_new = v.x * sin_rad + v.z * cos_rad
		# Translate vertex back and add to the result
		rotated_vertices.append(Vector3(x_new, v.y, z_new) + center)
	
	return rotated_vertices

# Helper function to rotate UV coordinates
func rotate_uv(uv: Vector2, angle_degrees: float, center: Vector2 = Vector2(0.5, 0.5)) -> Vector2:
	var rad = deg_to_rad(angle_degrees)
	var cos_rad = cos(rad)
	var sin_rad = sin(rad)

	# Translate UV to origin
	uv -= center

	# Rotate UV
	var x_new = uv.x * cos_rad - uv.y * sin_rad
	var y_new = uv.x * sin_rad + uv.y * cos_rad

	# Translate UV back
	uv = Vector2(x_new, y_new) + center
	return uv


# Only newly created blocks will need this calculation
# Previously saved blocks do not.
func get_block_rotation(shape: String, tilerotation: int = 0) -> int:
	var defaultRotation: int = 0
	if shape == "slope":
		defaultRotation = 90
	# The slope has a default rotation of 90
	# The block has a default rotation of 0
	var myRotation: int = tilerotation + defaultRotation
	if myRotation == 0:
		# Only the block will match this case, not the slope. The block points north
		return myRotation+180
	elif myRotation == 90:
		# A block will point east
		# A slope will point north
		return myRotation+0
	elif myRotation == 180:
		# A block will point south
		# A slope will point east
		return myRotation-180
	elif myRotation == 270:
		# A block will point west
		# A slope will point south
		return myRotation+0
	elif myRotation == 360:
		# Only a slope can match this case if it's rotation is 270 and it gets 90 rotation by default
		return myRotation-180
	return myRotation
