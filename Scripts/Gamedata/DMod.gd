class_name DMod
extends RefCounted

# This class represents a mod with its properties
# Example mod json:
#{
#  "id": "core",
#  "name": "Core",
#  "version": "1.0.0",
#  "description": "This is the core mod of the game. It provides the foundational systems and data required for other mods to function.",
#  "author": "Your Name or Studio Name",
#  "dependencies": [],
#  "homepage": "https://github.com/Khaligufzel/Dimensionfall",
#  "license": "GPL-3.0 License",
#  "tags": ["core", "base", "foundation"]
#}

# Properties defined in the mod
var id: String
var name: String
var version: String
var description: String
var author: String
var dependencies: Array = []
var homepage: String
var license: String
var tags: Array = []
var parent: DMods  # Reference to the parent DMods container

var maps: DMaps
var tacticalmaps: DTacticalmaps
var furnitures: DFurnitures
var items: DItems
var tiles: DTiles
var mobs: DMobs
var itemgroups: DItemgroups
var playerattributes: DPlayerAttributes
var wearableslots: DWearableSlots
var skills: DSkills
var stats: DStats
var quests: DQuests
var overmapareas: DOvermapareas
var mobgroups: DMobgroups


var content_instances: Dictionary
# Enum for content types
enum ContentType {
	TACTICALMAPS,
	MAPS,
	FURNITURES,
	ITEMGROUPS,
	ITEMS,
	TILES,
	MOBS,
	PLAYERATTRIBUTES,
	WEARABLESLOTS,
	STATS,
	SKILLS,
	QUESTS,
	OVERMAPAREAS,
	MOBGROUPS
}

# Constructor to initialize mod properties and associated content types
# modinfo: the data as loaded from json
# myparent: The list containing all mods
func _init(modinfo: Dictionary, myparent: DMods):
	parent = myparent
	id = modinfo.get("id", "")
	name = modinfo.get("name", "")
	version = modinfo.get("version", "")
	description = modinfo.get("description", "")
	author = modinfo.get("author", "")
	dependencies = modinfo.get("dependencies", [])
	homepage = modinfo.get("homepage", "")
	license = modinfo.get("license", "")
	tags = modinfo.get("tags", [])

	maps = DMaps.new()
	tacticalmaps = DTacticalmaps.new()
	furnitures = DFurnitures.new()
	items = DItems.new()
	tiles = DTiles.new()
	mobs = DMobs.new()
	itemgroups = DItemgroups.new()
	playerattributes = DPlayerAttributes.new()
	wearableslots = DWearableSlots.new()
	skills = DSkills.new()
	stats = DStats.new(id)  # Pass the mod_id for stats initialization
	quests = DQuests.new()
	overmapareas = DOvermapareas.new()
	mobgroups = DMobgroups.new()

	# Initialize content type instances specific to this mod
	content_instances = {
		ContentType.TACTICALMAPS: tacticalmaps,
		ContentType.MAPS: maps,
		ContentType.FURNITURES: furnitures,
		ContentType.ITEMGROUPS: itemgroups,
		ContentType.ITEMS: items,
		ContentType.TILES: tiles,
		ContentType.MOBS: mobs,
		ContentType.PLAYERATTRIBUTES: playerattributes,
		ContentType.WEARABLESLOTS: wearableslots,
		ContentType.STATS: stats,
		ContentType.SKILLS: skills,
		ContentType.QUESTS: quests,
		ContentType.OVERMAPAREAS: overmapareas,
		ContentType.MOBGROUPS: mobgroups
	}


# Method to retrieve a specific content type instance
# type: The content type enum value
func get_data_of_type(type: ContentType) -> RefCounted:
	if content_instances.has(type):
		return content_instances[type]
	else:
		print_debug("Content type not found: " + str(type))
		return null


# Get data function to return a dictionary with all properties
func get_modinfo() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"version": version,
		"description": description,
		"author": author,
		"dependencies": dependencies,
		"homepage": homepage,
		"license": license,
		"tags": tags
	}

# Method to save any changes to the mod back to disk
func save_to_disk():
	parent.save_mods_to_disk()

# A mod is being deleted from the data
# This will remove it from its parent and save changes
func delete():
	parent.remove_mod(id)
	parent.save_mods_to_disk()
