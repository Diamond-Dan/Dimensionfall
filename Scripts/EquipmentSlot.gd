extends Control

# This script is intended to be used with the EquipmentSlot scene
# The equipmentslot will hold one piece of equipment
# The equipment will be represented by en InventoryItem
# The equipment will be visualized by a texture provided by the InventoryItem
# There will be signals for equipping, unequipping and clearing the slot
# The user will be able to drop equipment onto this slot to equip it
# When the item is equipped, it will be removed from the inventory that is 
# currently assigned to the InventoryItem
# If the inventory that is assigned to the InventoryItem is different then the player inventory
# when the item is equipped, we will update the inventory of the InventoryItem to be 
# the player inventory
# There will be functions to serialize and deserialize the inventoryitem


@export var myInventory: InventoryStacked
@export var backgroundColor: ColorRect
@export var myIcon: TextureRect
# A timer that will prevent the user from reloading while a reload is happening now
@export var otherHandSlot: Control
@export var is_left_slot: bool = true

var myInventoryItem: InventoryItem = null
var myMagazine: InventoryItem = null
# The node that will actually operate the item
var equippedItem: Sprite3D = null
var can_reload: bool = true
var default_reload_speed: float = 1.0

# Signals
signal item_was_equipped(equippedItem: InventoryItem, equipmentSlot: Control)
signal item_was_cleared(equippedItem: InventoryItem, equipmentSlot: Control)

# Called when the node enters the scene tree for the first time.
func _ready():
	item_was_equipped.connect(Helper.signal_broker.on_item_equipped)
	item_was_cleared.connect(Helper.signal_broker.on_item_slot_cleared)


# Handle GUI input events
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if there's an item equipped and the click is inside the slot
		if myInventoryItem:
			unequip()


# Equip an item
func equip(item: InventoryItem) -> void:
	# First unequip any currently equipped item
	if myInventoryItem:
		unequip()

	if item:
		var is_two_handed: bool = item.get_property("two_handed", false)
		var other_slot_item: InventoryItem = otherHandSlot.get_item()
		# Check if the other slot has a two-handed item equipped
		if other_slot_item and other_slot_item.get_property("two_handed", false):
			print_debug("Cannot equip item. The other slot has a two-handed weapon equipped.")
			return
		
		myInventoryItem = item
		update_icon()
		# Remove the item from its original inventory
		# Not applicable if a game is loaded and we re-equip an item that was alread equipped
		var itemInventory = item.get_inventory()
		if itemInventory and itemInventory.has_item(item):
			item.get_inventory().remove_item(item)	
		
		# If the item is two-handed, clear the other hand slot before equipping
		if is_two_handed:
			otherHandSlot.unequip()
		item_was_equipped.emit(item, self)


# Unequip the current item
func unequip() -> void:
	if myInventoryItem:
		item_was_cleared.emit(myInventoryItem, self)
		myInventoryItem.clear_property("equipped_laft")
		myInventory.add_item(myInventoryItem)
		myInventoryItem = null
		if myMagazine:
			myInventory.add_item(myMagazine)
			myMagazine = null
		update_icon()


# Update the icon of the equipped item
func update_icon() -> void:
	if myInventoryItem:
		myIcon.texture = myInventoryItem.get_texture()
		myIcon.visible = true
	else:
		myIcon.texture = null
		myIcon.visible = false


# Serialize the equipped item
func serialize() -> Dictionary:
	if myInventoryItem:
		return myInventoryItem.serialize()
	return {}


# Deserialize and equip an item
func deserialize(data: Dictionary) -> void:
	if data.size() > 0:
		var item = InventoryItem.new()
		item.deserialize(data)
		equip(item)


# The reload has completed. We now need to remove the current magazine and put in a new one
func reload_weapon(item: InventoryItem):
	if myInventoryItem and not myInventoryItem.get_property("Ranged") == null and item == myInventoryItem:
		var oldMagazine = myMagazine
		remove_magazine()
		can_reload = true
		insert_magazine(oldMagazine)


func insert_magazine(oldMagazine = InventoryItem):
	if not myInventoryItem or myInventoryItem.get_property("Ranged") == null:
		return  # Ensure the item is a ranged weapon
	
	# Assuming the inventory has a method to find a compatible magazine.
	var magazine = find_compatible_magazine(oldMagazine)
	if magazine:
		myMagazine = magazine
		myInventory.remove_item(magazine)  # Remove the magazine from the inventory
		equippedItem.on_magazine_inserted()


func remove_magazine():
	if not myInventoryItem or not myInventoryItem.get_property("Ranged") or not myMagazine:
		return  # Ensure the item is a ranged weapon

	myInventory.add_item(myMagazine)
	equippedItem.on_magazine_removed()
	myMagazine = null


func get_magazine() -> InventoryItem:
	return myMagazine


func get_item() -> InventoryItem:
	return myInventoryItem


# This function will loop over the items in the inventory
# It will select items that have the "magazine" property
# It will return the first result if a magazine is found
# It will return null of no magazine is found
func find_compatible_magazine(oldMagazine: InventoryItem) -> InventoryItem:
	var inventoryItems: Array = myInventory.get_items()  # Retrieve all items in the inventory
	for item in inventoryItems:
		# Check if the item is a magazine and is compatible with the equipped weapon
		if not item.get_property("Magazine") == null and not item == oldMagazine:
			var magazine = item.get_property("Magazine")
			if magazine.has("current_ammo"):
				if int(magazine.current_ammo) > 0:
					return item
	return null  # Return null if no compatible magazine is found
