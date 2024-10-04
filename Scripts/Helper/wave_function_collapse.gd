extends RefCounted

# This script provides support and interface for the https://github.com/BenjaTK/Gaea/tree/main addon
# Specifically the wave function collapse
# This script will process DMaps, create the required Gaea components
# and finally return a grid of TileInfo that can be used in the overmap_manager.
# See https://github.com/Khaligufzel/Dimensionfall/issues/411 for the initial implementation idea


# Created once, holds all possible tile entries and their neighbors
var tileentrylist: Array = []

func create_collapsed_grid() -> GaeaGrid:
	var mygrid: GaeaGrid
	create_tile_entries()
	return mygrid


# An algorithm that loops over all Gamedata.maps and creates a OMWaveFunction2DEntry for: 1. each rotation of the map. 2. each neighbor key. So one map can have a maximum of 4 TileInfo variants, multiplied by the amount of neighbor keys. Next, in order to give every rotated variant their appropriate neighbors, we have to loop over all eligible maps and each of their rotations. Actually we might skip this process for maps that have 0 or 4 connections since they fit either everywhere or nowhere. Let's say we use urban and suburban neighbor keys, where urban will be the inner city core and suburban will be the outer area. In this case, the maps in the urban category will have connections with the urban and suburban category and the suburban category will have connections with the suburban and wilderness/plains category. This creates a one-way expansion outwards.
func create_tile_entries() -> void:
	tileentrylist.clear()
	var maps: Dictionary = Gamedata.maps.get_all()
	for map: DMap in maps:
		for key in map.neighbor_keys.keys():
			var rotations: Array = [0,90,180,270]
			for myrotation in rotations:
				var mytileinfo: OvermapTileInfo = OvermapTileInfo.new()
				mytileinfo.rotation = myrotation
				mytileinfo.key = key
				mytileinfo.dmap = map
				mytileinfo.id = map.id + "_" + str(key) + "_" + str(myrotation)
				var myomentry: OMWaveFunction2DEntry = OMWaveFunction2DEntry.new()
				myomentry.tile_info = mytileinfo
				tileentrylist.append(myomentry)


func apply_neighbors():
	for tile: OMWaveFunction2DEntry in tileentrylist:
		var mytileinfo: OvermapTileInfo = tile.tile_info


func get_neighbors_for_tile(tileentry: OMWaveFunction2DEntry):
	tileentry.clear_neighbors()
	var mytileinfo: OvermapTileInfo = tileentry.tile_info
	# Step 1: only consider tile entries that match the neighbor key
	var considered_tiles: Array = get_neighbors_by_key(mytileinfo)
	# Step 2: Exclude all tiles that are unable to connect due to their connection types
	# For example, a crossroads has to match with another road and cannot match with a field
	# This does not exclue tiles that have both road and ground connections 
	# unless mytileinfo is water or something
	considered_tiles = exclude_connections_basic(considered_tiles, mytileinfo)
	# Step 3: Of the remaining maps, consider each rotation. Exclude all rotations that do not have a 
	# matching connection type on this direction. If the map itself is rotated, for example by 90 degrees,
	# we will now have to exclude all maps that have a connection to that direction
	# (since the north is now facing the west due to rotation)
	considered_tiles = exclude_invalid_rotations(considered_tiles, mytileinfo)

	# You can now return or process the remaining considered tiles
	return considered_tiles


# Returns a list of OMWaveFunction2DEntry by filtering the tileentrylist by neighbor keys
# The OMWaveFunction2DEntry's key must be included
func get_neighbors_by_key(mytileinfo: OvermapTileInfo) -> Array:
	var considered_tiles: Array = []
	for tile: OMWaveFunction2DEntry in tileentrylist:
		var tileinfo: OvermapTileInfo = tile.tile_info
		# Loop over directions north, east, south, west
		for direction: String in mytileinfo.dmap.neighbors.keys():
			if  mytileinfo.dmap.neighbors[direction].has(tileinfo.key):
				considered_tiles.append(tile)
				break # We must consider this tile when at least one direction  has the key
	return considered_tiles


# Basic check to see if the tiles in the list are able to match with this tile's connection
# The tile will be considered if any of its connection types match any of this tile's connection types.
# The direction doesn't matter.
func exclude_connections_basic(considered_tiles: Array, mytileinfo: OvermapTileInfo) -> Array:
	var newconsiderations: Array = []
	var myconnections: Dictionary = mytileinfo.dmap.connections # example: {"south": "road","west": "ground"}

	for tile: OMWaveFunction2DEntry in considered_tiles:
		var tileinfo: OvermapTileInfo = tile.tile_info
		var tileconnections: Dictionary = tileinfo.dmap.connections

		# Check if any connection type in mytileinfo matches any connection type in tileinfo
		var has_matching_connection: bool = false
		for myconnection_type in myconnections.values():
			if myconnection_type in tileconnections.values():
				has_matching_connection = true
				break # Exit loop once a match is found

		# If there is a matching connection type, add the tile to the new considerations list
		if has_matching_connection:
			newconsiderations.append(tile)

	return newconsiderations


# Exclude tiles based on their rotation and mismatched connection types
func exclude_invalid_rotations(considered_tiles: Array, mytileinfo: OvermapTileInfo) -> Array:
	var myconnections = mytileinfo.dmap.connections

	# Define rotation mappings for how the directions shift depending on rotation
	var rotation_map = {
		0: {"north": "north", "east": "east", "south": "south", "west": "west"},
		90: {"north": "west", "east": "north", "south": "east", "west": "south"},
		180: {"north": "south", "east": "west", "south": "north", "west": "east"},
		270: {"north": "east", "east": "south", "south": "west", "west": "north"}
	}

	var final_considered_tiles: Array = []

	# Get the adjusted directions for the current tile (mytileinfo)
	var my_rotated_connections = rotation_map[mytileinfo.rotation]

	for tile: OMWaveFunction2DEntry in considered_tiles:
		var tileinfo: OvermapTileInfo = tile.tile_info
		var tileconnections = tileinfo.dmap.connections

		# Get the adjusted directions for the candidate tile (tileinfo)
		var tile_rotated_connections = rotation_map[tileinfo.rotation]

		var exclude_tile = false

		# Loop over each direction and check the connections based on both rotations
		for direction in ["north", "east", "south", "west"]:
			# Adjust direction for mytileinfo based on its rotation
			var my_adjusted_direction = my_rotated_connections[direction]
			var my_connection_type = myconnections[my_adjusted_direction]

			# Adjust direction for the candidate tile (tileinfo) based on its rotation
			var tile_adjusted_direction = tile_rotated_connections[direction]
			var tile_connection_type = tileconnections[tile_adjusted_direction]

			# Exclude the candidate tile if the connection types don't match
			if my_connection_type != tile_connection_type:
				exclude_tile = true
				break  # Exclude if any connection doesn't match

		# Only include the tile if all connections are valid
		if not exclude_tile:
			final_considered_tiles.append(tile)

	return final_considered_tiles
